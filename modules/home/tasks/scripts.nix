{ pkgs, ... }:
let
  # TODO use something similar to modules/home/scripts
  gen-task-link =
    pkgs.writeShellApplication
      {
        name = "gen-task-link";
        text =
          ''
            # description target_file
            read -r description
            task add "$description" >> /dev/null
            UUID="$(task +LATEST uuids)"
            echo "[Redirect]($1#$UUID)" > ~/Documents/vw/tasks/"$UUID".md
            echo "[[**$UUID**|$1]]" > /tmp/task-link
          '';
      };
  create-task-from-heading =
    pkgs.writeShellApplication
      {
        name = "create-task-from-heading";
        runtimeInputs = [ pkgs.taskwarrior3 ];
        text =
          ''
            # Usage: create-task-from-heading "Description" "file/path.md" "heading-anchor" ["checklist-item"]
            DESCRIPTION="$1"
            FILE_PATH="$2"
            ANCHOR="$3"
            CHECKLIST_ITEM="''${4:-}"

            # Create task with description
            task add "$DESCRIPTION" >> /dev/null
            UUID="$(task +LATEST uuids)"

            # Create markdown file with link - include checklist item if present
            if [ -n "$CHECKLIST_ITEM" ]; then
              echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
              echo "CHECKLIST:$CHECKLIST_ITEM" >> ~/Documents/vw/tasks/"$UUID".md
              echo "Created task $UUID: $DESCRIPTION -> $FILE_PATH#$ANCHOR (checklist item)"
            else
              echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
              echo "Created task $UUID: $DESCRIPTION -> $FILE_PATH#$ANCHOR"
            fi
          '';
      };
  update-task-link =
    pkgs.writeShellApplication
      {
        name = "update-task-link";
        runtimeInputs = [ pkgs.taskwarrior3 pkgs.fzf ];
        text =
          ''
            # Usage: update-task-link "file/path.md" "heading-anchor" ["checklist-item"]
            FILE_PATH="$1"
            ANCHOR="$2"
            CHECKLIST_ITEM="''${3:-}"

            # Select task using fzf
            SELECTED=$(task status:pending export | ${pkgs.jq}/bin/jq -r '.[] | "\(.uuid) \(.description)"' | fzf --prompt="Select task to update: ")

            if [ -z "$SELECTED" ]; then
              echo "No task selected"
              exit 1
            fi

            UUID=$(echo "$SELECTED" | awk '{print $1}')

            # Update the redirect link - include checklist item if present
            if [ -n "$CHECKLIST_ITEM" ]; then
              echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
              echo "CHECKLIST:$CHECKLIST_ITEM" >> ~/Documents/vw/tasks/"$UUID".md
              echo "Updated task $UUID to point to $FILE_PATH#$ANCHOR (checklist item)"
            else
              echo "[Redirect]($FILE_PATH#$ANCHOR)" > ~/Documents/vw/tasks/"$UUID".md
              echo "Updated task $UUID to point to $FILE_PATH#$ANCHOR"
            fi
          '';
      };
  taskopen-smart =
    pkgs.writeShellApplication
      {
        name = "taskopen-smart";
        runtimeInputs = [ pkgs.neovim ];
        text =
          ''
            # Usage: taskopen-smart ~/Documents/vw/tasks/$UUID.md "Task Description"
            TASK_FILE="$1"
            TASK_DESCRIPTION="$2"

            # Create file if it doesn't exist
            if ! [ -e "$TASK_FILE" ]; then
              echo "# $TASK_DESCRIPTION" > "$TASK_FILE"
            fi

            # Check if file has a redirect link
            if grep -q "^\[Redirect\]" "$TASK_FILE"; then
              # Check if file has a checklist item
              if grep -q "^CHECKLIST:" "$TASK_FILE"; then
                CHECKLIST_TEXT=$(grep "^CHECKLIST:" "$TASK_FILE" | sed 's/^CHECKLIST://')
                # Open file and follow link, then search for checklist item
                vim "$TASK_FILE" \
                  -c "VimwikiFollowLink" \
                  -c "normal! gg" \
                  -c "call search('\\V$CHECKLIST_TEXT', 'c')"
              else
                # Just follow the link normally
                vim "$TASK_FILE" -c "VimwikiFollowLink"
              fi
            else
              # No redirect, just edit the notes file
              vim "$TASK_FILE"
            fi
          '';
      };
  edit-note = bin
    (pkgs.writeShellApplication
      {
        name = "edit-note";
        text =
          ''
            if ! [ -e "$1" ]
            then
              echo \# "$2" >> "$1"
            fi
            vim "$1"
          '';
      });
  bin = pkg: "${pkg}/bin/${pkg.name}";
in
{

  home.packages = with pkgs;
    [
      gen-task-link
      create-task-from-heading
      update-task-link
      taskopen-smart
      taskopen
    ];

  home.file.".taskopenrc".text =
    ''
      [General]
      no_annotation_hook="${bin taskopen-smart} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""

      [Actions]
      notes.regex = "^Notes"
      notes.command = "${edit-note} ~/Documents/vw/tasks/$UUID.md \"$TASK_DESCRIPTION\""
    '';
}
