#!/usr/bin/env python3
"""
Import reminders from iCloud Drive files to Taskwarrior
"""

import os
import sys
import subprocess
from pathlib import Path

try:
    from pyicloud import PyiCloudService
except ImportError:
    print("Error: pyicloud not found.", file=sys.stderr)
    sys.exit(1)


def get_icloud_credentials():
    """Get iCloud credentials from environment or config file."""
    username = os.environ.get("ICLOUD_USERNAME")
    password = os.environ.get("ICLOUD_PASSWORD")

    if not username or not password:
        config_file = Path.home() / ".config" / "icloud-sync" / "credentials"
        if config_file.exists():
            with open(config_file) as f:
                lines = f.read().strip().split('\n')
                if len(lines) >= 2:
                    username = lines[0]
                    password = lines[1]

    if not username or not password:
        print("Error: iCloud credentials not found.", file=sys.stderr)
        sys.exit(1)

    return username, password


def add_task_from_reminder(title: str):
    """Add a task to taskwarrior with the given title."""
    try:
        subprocess.run(
            ["task", "add", title],
            check=True,
            capture_output=True
        )
        print(f"  ✓ Created task: {title}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"  ✗ Failed to create task: {title}")
        print(f"    Error: {e.stderr.decode() if e.stderr else str(e)}")
        return False


def process_reminders():
    """Process reminder files from iCloud Drive."""
    username, password = get_icloud_credentials()

    print("Authenticating with iCloud...")
    api = PyiCloudService(username, password)

    if api.requires_2fa:
        print("Two-factor authentication required.")
        code = input("Enter the code you received: ")
        result = api.validate_2fa_code(code)
        if not result:
            print("Failed to verify security code")
            sys.exit(1)

        if not api.is_trusted_session:
            print("Session is not trusted. Requesting trust...")
            result = api.trust_session()

    print("\nAccessing iCloud Drive...")
    drive = api.drive

    # Navigate to Shortcuts/reminders folder
    try:
        # Navigate to the Shortcuts/reminders folder path
        # pyicloud uses a path-based approach
        try:
            shortcuts_folder = drive["Shortcuts"]
        except Exception as e:
            print(f"Error: Could not find 'Shortcuts' folder in iCloud Drive: {e}")
            print("Make sure the Shortcuts folder exists in your iCloud Drive")
            sys.exit(1)

        try:
            reminders_folder = shortcuts_folder["reminders"]
        except Exception as e:
            print(f"Error: Could not find 'reminders' folder in Shortcuts: {e}")
            print("Make sure you have a 'reminders' folder inside Shortcuts/")
            print("\nNo reminders to import. Exiting.")
            sys.exit(0)

        # Get all files in reminders folder
        # dir() returns a list of filename strings
        filenames = reminders_folder.dir()

        if not filenames:
            print("No reminder files found. Nothing to import.")
            return

        print(f"Found {len(filenames)} reminder file(s)")

        processed = 0
        for filename in filenames:
            print(f"\nProcessing: {filename}")

            # Try to get file content (the title might be in the content or filename)
            try:
                # Get the file object from the folder
                file_obj = reminders_folder[filename]

                # Download file content
                with file_obj.open(stream=True) as response:
                    content = response.raw.read().decode('utf-8', errors='ignore').strip()

                # Use content as task title if it exists, otherwise use filename
                task_title = content if content else filename

                # Create the task
                if add_task_from_reminder(task_title):
                    # Delete the file after successful import
                    file_obj.delete()
                    print(f"  ✓ Deleted file: {filename}")
                    processed += 1
            except Exception as e:
                print(f"  ✗ Error processing file: {e}")
                continue

        print(f"\n✓ Successfully imported {processed} reminder(s)")

    except Exception as e:
        print(f"Error accessing iCloud Drive: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    try:
        process_reminders()
    except KeyboardInterrupt:
        print("\nImport cancelled.")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
