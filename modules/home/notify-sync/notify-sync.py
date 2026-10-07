"""Mirror this host's notifications onto a peer's notification server.

Watches the local session bus for Notify calls and their replies, then re-sends
each notification to the peer's bus, without actions. Dismissing either copy
dismisses the other, and an app closing its notification closes the mirror.
Expiry is not synced: both copies carry the same timeout and expire on their own.
"""

import argparse
import asyncio
import logging
import socket
from dataclasses import dataclass

from dbus_fast import Message, MessageFlag, MessageType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.errors import AuthError

NOTIFICATIONS = "org.freedesktop.Notifications"
NOTIFICATIONS_PATH = "/org/freedesktop/Notifications"
MARKER = "x-notify-sync"
# Mako config matches this to give mirrors their own click binding.
MIRROR_ENTRY = "notify-sync"
DISMISSED = 2
CLOSED = 3
RETRY_SECONDS = 10
CONNECT_TIMEOUT = 5

MONITOR_RULES = [
    f"type='method_call',interface='{NOTIFICATIONS}',member='Notify'",
    f"type='method_return',sender='{NOTIFICATIONS}'",
    f"type='error',sender='{NOTIFICATIONS}'",
    f"type='signal',sender='{NOTIFICATIONS}',interface='{NOTIFICATIONS}',member='NotificationClosed'",
]
PEER_RULES = [
    f"type='signal',sender='{NOTIFICATIONS}',interface='{NOTIFICATIONS}',member='NotificationClosed'",
    f"type='signal',sender='org.freedesktop.DBus',member='NameOwnerChanged',arg0='{NOTIFICATIONS}'",
]

log = logging.getLogger("notify-sync")


def bus_method(member, signature="", body=(), interface="org.freedesktop.DBus"):
    return Message(
        destination="org.freedesktop.DBus",
        path="/org/freedesktop/DBus",
        interface=interface,
        member=member,
        signature=signature,
        body=list(body),
    )


async def checked_call(bus, message):
    reply = await bus.call(message)
    if reply.message_type is MessageType.ERROR:
        raise RuntimeError(f"{message.member}: {reply.error_name} {reply.body}")
    return reply


class PeerBus(MessageBus):
    # dbus-fast 4.0.4 loops forever on EOF here, and since sock_recv returns
    # without yielding, that freezes the whole event loop. This is upstream's
    # fix (in 5.x); drop the override once nixpkgs ships it.
    async def _auth_readline(self):
        buf = b""
        while buf[-2:] != b"\r\n":
            chunk = await self._loop.sock_recv(self._sock, 1024)
            if not chunk:
                raise AuthError("connection closed during authentication")
            buf += chunk
        return buf[:-2].decode()


@dataclass
class Original:
    args: list
    mirror: int | None = None
    # The mirror expired; don't bring it back when replaying.
    settled: bool = False


class Bridge:
    def __init__(self, makoctl, ignore):
        self.makoctl = makoctl
        self.ignore = {app.casefold() for app in ignore}
        self.host = socket.gethostname()
        self.events = asyncio.Queue()
        self.originals: dict[int, Original] = {}
        self.mirrors: dict[int, int] = {}
        # Mirrors to close once the peer is back.
        self.stale: set[int] = set()
        # Notify calls awaiting the reply that carries their id.
        self.pending: dict[tuple[str, int], list] = {}
        self.peer = None
        # Mirror ids are only meaningful to the server instance that issued them.
        self.server = None

    async def watch_local(self):
        bus = await MessageBus().connect()
        await checked_call(bus, bus_method(
            "BecomeMonitor", "asu", [MONITOR_RULES, 0],
            interface="org.freedesktop.DBus.Monitoring"))
        bus.add_message_handler(self.on_local)
        await bus.wait_for_disconnect()
        raise RuntimeError("lost the local session bus")

    def on_local(self, msg):
        kind = msg.message_type
        if kind is MessageType.METHOD_CALL:
            if self.wanted(msg):
                self.pending[(msg.sender, msg.serial)] = msg.body
        elif kind is MessageType.METHOD_RETURN:
            body = self.pending.pop((msg.destination, msg.reply_serial), None)
            if body is not None:
                self.events.put_nowait((self.notify, msg.body[0], body))
        elif kind is MessageType.ERROR:
            self.pending.pop((msg.destination, msg.reply_serial), None)
        else:
            self.events.put_nowait((self.original_closed, *msg.body))
        # Monitors may not send, so claim everything to suppress automatic replies.
        return True

    def wanted(self, msg):
        if msg.flags & MessageFlag.NO_REPLY_EXPECTED:
            return False
        app, hints = msg.body[0], msg.body[6]
        return MARKER not in hints and app.casefold() not in self.ignore

    async def watch_peer(self, address):
        while True:
            bus = None
            try:
                bus = PeerBus(bus_address=address)
                # The far end of a live tunnel may never answer the handshake.
                await asyncio.wait_for(bus.connect(), CONNECT_TIMEOUT)
                bus.add_message_handler(self.on_peer)
                for rule in PEER_RULES:
                    await checked_call(bus, bus_method("AddMatch", "s", [rule]))
            except Exception as e:
                log.debug("peer unavailable: %r", e)
                if bus is not None:
                    bus.disconnect()
                await asyncio.sleep(RETRY_SECONDS)
                continue
            log.info("connected to peer")
            self.events.put_nowait((self.connected, bus))
            try:
                await bus.wait_for_disconnect()
            except Exception as e:
                # A dropped tunnel surfaces as EOFError rather than a clean disconnect.
                log.debug("peer connection lost: %s", e)
            log.info("disconnected from peer")
            self.events.put_nowait((self.disconnected, bus))
            await asyncio.sleep(RETRY_SECONDS)

    def on_peer(self, msg):
        if msg.message_type is not MessageType.SIGNAL:
            return
        if msg.member == "NotificationClosed":
            self.events.put_nowait((self.mirror_closed, *msg.body))
        elif msg.member == "NameOwnerChanged":
            self.events.put_nowait((self.server_changed, msg.body[2] or None))

    async def run_events(self):
        while True:
            handler, *args = await self.events.get()
            try:
                await handler(*args)
            except Exception:
                log.exception("%s%s failed", handler.__name__, tuple(args))

    async def notify(self, oid, body):
        app, _, icon, summary, text, _, hints, timeout = body
        hints = {
            **hints,
            MARKER: Variant("s", self.host),
            "desktop-entry": Variant("s", MIRROR_ENTRY),
        }
        original = self.originals.setdefault(oid, Original([]))
        original.args = [app, icon, summary, text, hints, timeout]
        original.settled = False
        await self.mirror(oid)

    async def mirror(self, oid):
        if self.peer is None:
            return
        original = self.originals[oid]
        app, icon, summary, text, hints, timeout = original.args
        reply = await self.call_peer(
            "Notify", "susssasa{sv}i",
            [app, original.mirror or 0, icon, summary, text, [], hints, timeout])
        if original.mirror is not None:
            self.mirrors.pop(original.mirror, None)
        original.mirror = reply.body[0]
        self.mirrors[original.mirror] = oid

    async def original_closed(self, oid, reason):
        original = self.originals.pop(oid, None)
        if original is None or original.mirror is None:
            return
        self.mirrors.pop(original.mirror, None)
        if reason in (DISMISSED, CLOSED):
            await self.close_mirror(original.mirror)

    async def close_mirror(self, mid):
        if self.peer is None:
            self.stale.add(mid)
            return
        await self.call_peer("CloseNotification", "u", [mid])

    async def mirror_closed(self, mid, reason):
        oid = self.mirrors.pop(mid, None)
        if oid is None:
            return
        original = self.originals[oid]
        original.mirror = None
        original.settled = True
        if reason == DISMISSED:
            del self.originals[oid]
            # Unlike CloseNotification, this reports a user dismissal to the app.
            dismiss = await asyncio.create_subprocess_exec(
                self.makoctl, "dismiss", "-n", str(oid))
            await dismiss.wait()

    async def connected(self, bus):
        self.peer = bus
        bus_id = (await checked_call(bus, bus_method("GetId"))).body[0]
        owner = await bus.call(bus_method("GetNameOwner", "s", [NOTIFICATIONS]))
        owner = owner.body[0] if owner.message_type is MessageType.METHOD_RETURN else None
        if self.server not in (None, (bus_id, owner)):
            self.forget_mirrors()
        self.server = (bus_id, owner)
        for mid in self.stale:
            await self.close_mirror(mid)
        self.stale.clear()
        for oid, original in list(self.originals.items()):
            if not original.settled and oid in self.originals:
                await self.mirror(oid)

    async def disconnected(self, bus):
        if self.peer is bus:
            self.peer = None

    async def server_changed(self, owner):
        if self.server is not None:
            self.server = (self.server[0], owner)
        self.forget_mirrors()

    def forget_mirrors(self):
        log.info("peer notification server changed; forgetting mirror ids")
        for original in self.originals.values():
            original.mirror = None
        self.mirrors.clear()
        self.stale.clear()

    async def call_peer(self, member, signature, body):
        return await checked_call(self.peer, Message(
            destination=NOTIFICATIONS,
            path=NOTIFICATIONS_PATH,
            interface=NOTIFICATIONS,
            member=member,
            signature=signature,
            body=body,
        ))


async def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--peer", required=True, help="D-Bus address of the peer's session bus")
    parser.add_argument("--makoctl", default="makoctl")
    parser.add_argument("--ignore", action="append", default=[], metavar="APP",
                        help="app name to keep local (case-insensitive)")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    bridge = Bridge(args.makoctl, args.ignore)
    await asyncio.gather(
        bridge.watch_local(),
        bridge.watch_peer(args.peer),
        bridge.run_events(),
    )


if __name__ == "__main__":
    asyncio.run(main())
