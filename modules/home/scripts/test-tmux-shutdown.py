#!/usr/bin/env python3
"""Exercise the installed logout hook against disposable tmux scopes.

Runs a normal checkpoint of the live desktop, then re-arms the logout hook.
The tmux server and pane stopped by this test use a private socket and no user
tmux configuration. Run with: just test-tmux-shutdown
"""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import uuid


SAVE_UNIT = "save-tmux-on-exit.service"
TIMER_UNIT = "save-tmux.timer"
STOPPING = "de5b426a63be47a7b6ac3eaac82e2f6f"
STOPPED = "9d1aaa27d60140bd96365438aad20286"


def run(*args, check=True, **kwargs):
    return subprocess.run(
        args, check=check, text=True, capture_output=True, **kwargs
    )


def property_of(unit, name):
    return run("systemctl", "--user", "show", unit, "-p", name, "--value").stdout.strip()


def live_panes():
    return set(
        run("tmux", "list-panes", "-a", "-F", "#{pane_id}:#{pane_pid}")
        .stdout.splitlines()
    )


def main():
    assert property_of(SAVE_UNIT, "ActiveState") == "active", "Logout hook must be armed"
    assert property_of("save-tmux.service", "ActiveState") == "inactive", "A save is in progress"
    before = live_panes()
    timer_active = property_of(TIMER_UNIT, "ActiveState") == "active"
    token = uuid.uuid4().hex
    root = Path(tempfile.mkdtemp(prefix="tmux-shutdown-", dir="/tmp/opencode"))
    socket = str(root / "socket")
    server_scope = f"app-ghostty-shutdown-test-{token}.scope"
    scopes = [server_scope]
    env = dict(os.environ)
    env.pop("TMUX", None)
    run("systemctl", "--user", "stop", TIMER_UNIT)

    try:
        run(
            "systemd-run", "--user", "--scope", "--quiet", f"--unit={server_scope}",
            "tmux", "-S", socket, "-f", "/dev/null", "new-session", "-d",
            "-s", "shutdown-test", "sleep 300", env=env,
        )
        # Keep the test server around after its last pane exits so both scope
        # stop jobs can be observed independently, including on broken configs.
        run("tmux", "-S", socket, "set-option", "-s", "exit-empty", "off", env=env)
        pane_pid = run(
            "tmux", "-S", socket, "display-message", "-p", "#{pane_pid}", env=env
        ).stdout.strip()
        for _ in range(50):
            pane_scope = Path(Path(f"/proc/{pane_pid}/cgroup").read_text().strip()).name
            if pane_scope.startswith("tmux-spawn-"):
                break
            time.sleep(0.1)
        assert pane_scope.startswith("tmux-spawn-") and pane_scope.endswith(".scope")
        scopes.insert(0, pane_scope)
        for scope in scopes:
            before_save = SAVE_UNIT in property_of(scope, "Before").split()
            print(f"{scope}: ordered before save at startup = {before_save}", flush=True)

        cursor = run("journalctl", "--user", "-n", "0", "--show-cursor").stdout
        cursor = next(
            line.removeprefix("-- cursor: ")
            for line in cursor.splitlines() if line.startswith("-- cursor: ")
        )
        stop = run("systemctl", "--user", "stop", SAVE_UNIT, *scopes, timeout=90, check=False)
        # Without ordering, killing the server can make its pane scope vanish
        # before systemctl submits that scope's stop job (exit 5).
        assert stop.returncode in (0, 5), stop.stderr
        save_stopped = int(property_of(SAVE_UNIT, "InactiveEnterTimestampMonotonic"))
        assert save_stopped > 0 and property_of(SAVE_UNIT, "Result") == "success"

        # Journal delivery may lag the completed systemctl job briefly.
        events = []
        for _ in range(50):
            output = run(
                "journalctl", "--user", f"--after-cursor={cursor}", "-o", "json",
                "--no-pager", "-u", SAVE_UNIT, "-u", server_scope, "-u", pane_scope,
            ).stdout
            events = [json.loads(line) for line in output.splitlines()]
            stopped = {e.get("USER_UNIT") for e in events if e.get("MESSAGE_ID") == STOPPED}
            if set(scopes) <= stopped:
                break
            time.sleep(0.1)

        result = {
            "stop_exit": stop.returncode,
            "save_finished_monotonic_usec": save_stopped,
            "scopes": {},
        }
        for scope in scopes:
            stops = [
                int(e["__MONOTONIC_TIMESTAMP"])
                for e in events
                if e.get("USER_UNIT") == scope and e.get("MESSAGE_ID") in (STOPPING, STOPPED)
            ]
            assert stops, f"No stop evidence for {scope}"
            result["scopes"][scope] = {
                "first_stop_monotonic_usec": min(stops),
                "survived_save": min(stops) >= save_stopped,
            }
        (root / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2))
        print(f"Evidence: {root}")
        assert before <= live_panes(), "A pre-existing pane changed during the test"
        assert all(s["survived_save"] for s in result["scopes"].values()), (
            "tmux server or pane teardown started before the save finished"
        )
        print("PASS: both the tmux server and its pane survived until saving completed")
    finally:
        run("tmux", "-S", socket, "kill-server", env=env, check=False)
        run("systemctl", "--user", "stop", *scopes, check=False)
        run("systemctl", "--user", "start", SAVE_UNIT)
        if timer_active:
            run("systemctl", "--user", "start", TIMER_UNIT)


if __name__ == "__main__":
    main()
