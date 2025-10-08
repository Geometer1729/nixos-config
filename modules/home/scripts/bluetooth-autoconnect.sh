#!/usr/bin/env bash

# Bluetooth auto-connect script
# Searches for paired devices matching pattern and attempts to connect to any available

# Wait a bit for bluetooth service to be ready
sleep 5

# Pattern to match Brian's headphones
DEVICE_PATTERN=".*(b|B)rian.*headphones.*"

# Get list of paired devices and find matching ones
DEVICES=$(bluetoothctl devices Paired)

# Search for devices matching the pattern
MATCHING_DEVICES=$(echo "$DEVICES" | grep -iE "$DEVICE_PATTERN")

if [ -n "$MATCHING_DEVICES" ]; then
    echo "Found matching devices:"
    echo "$MATCHING_DEVICES"

    # Try to connect to each matching device
    CONNECTED=false
    while IFS= read -r device_line; do
        if [ -n "$device_line" ]; then
            # Extract MAC address (second field) and device name
            MAC_ADDRESS=$(echo "$device_line" | awk '{print $2}')
            DEVICE_NAME=$(echo "$device_line" | cut -d' ' -f3-)

            echo "Checking device: $DEVICE_NAME ($MAC_ADDRESS)"

            # Check if device is already connected
            if bluetoothctl info "$MAC_ADDRESS" | grep -q "Connected: yes"; then
                echo "Device $DEVICE_NAME is already connected"
                CONNECTED=true
                break
            else
                echo "Attempting to connect to $DEVICE_NAME..."

                # Attempt to connect
                if bluetoothctl connect "$MAC_ADDRESS"; then
                    echo "Successfully connected to $DEVICE_NAME"
                    CONNECTED=true
                    break
                else
                    echo "Failed to connect to $DEVICE_NAME, trying next device..."
                fi
            fi
        fi
    done <<< "$MATCHING_DEVICES"

    if [ "$CONNECTED" = false ]; then
        echo "Failed to connect to any matching devices"
    fi
else
    echo "No paired devices found matching pattern: $DEVICE_PATTERN"
    echo "Available paired devices:"
    echo "$DEVICES"
fi