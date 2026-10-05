# Fail when the root or boot filesystem is nearly full.
limit=90
mounts=()
for mount in / /boot; do
  if mountpoint -q "$mount"; then
    mounts+=("$mount")
  fi
done

df -h --output=target,size,used,avail,pcent "${mounts[@]}"

status=0
while read -r target used; do
  if ((${used%\%} >= limit)); then
    echo "$target is $used full (limit $limit%)" >&2
    status=1
  fi
done < <(df --output=target,pcent "${mounts[@]}" | tail -n +2)
exit "$status"
