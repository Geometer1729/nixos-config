#!/usr/bin/env bash
# Reset yubikey when it's not detected by GPG/pcscd
# This fixes issues when unplugging the yubikey without properly disconnecting

set -euo pipefail

echo "Resetting YubiKey connection..."

# Kill any existing GPG/scdaemon processes
echo "Killing GPG components..."
gpgconf --kill all 2>/dev/null || true

# Stop pcscd
echo "Stopping pcscd..."
sudo systemctl stop pcscd.socket pcscd.service 2>/dev/null || true

# Reset the USB device
echo "Resetting USB device..."
if sudo usbreset 1050:0407 2>/dev/null; then
    echo "USB reset successful"
else
    echo "Warning: USB reset failed, but continuing..."
fi

# Start pcscd
echo "Starting pcscd..."
sudo systemctl start pcscd.socket

# Give it a moment to initialize
sleep 2

# Kill GPG components again to force reconnection
gpgconf --kill all 2>/dev/null || true

# Test if it works
echo ""
echo "Testing YubiKey detection..."
if gpg --card-status >/dev/null 2>&1; then
    echo "✓ YubiKey is now working!"
else
    echo "✗ YubiKey still not detected. You may need to physically unplug and replug it."
    exit 1
fi
