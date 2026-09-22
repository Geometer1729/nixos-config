# description target_file
read -r description
task add "$description" >> /dev/null
UUID="$(task +LATEST uuids)"
echo "[Redirect]($1#$UUID)" > ~/Documents/vw/tasks/"$UUID".md
echo "[[**$UUID**|$1]]" > /tmp/task-link
