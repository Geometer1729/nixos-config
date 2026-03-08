#!/usr/bin/env bash
# Show what's pulling GNOME into your NixOS closure and why

target="${1:-/run/current-system}"

echo "=== Got GNOMED? ==="
echo "Scanning closure of: $target"
echo ""

# Find all gnome-related packages in the closure, sorted by closure size descending
# Exclude this script itself from results
sorted_paths=$(nix path-info -rS "$target" 2>/dev/null \
    | grep -i gnome \
    | grep -v "got-gnomed" \
    | sort -t'	' -k2 -n -r || true)

if [[ -z "$sorted_paths" ]]; then
    echo "No GNOME packages found. You're clean!"
    exit 0
fi

total_closure=0
echo "--- GNOME packages in closure (by size) ---"
echo ""

while read -r line; do
    # nix path-info -rS output: path (with trailing spaces) <tab> size
    path=$(echo "$line" | sed 's/\t.*//' | xargs)
    size=$(echo "$line" | sed 's/.*\t//' | xargs)
    name=$(basename "$path" | sed 's/^[a-z0-9]\{32\}-//')
    human_size=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")
    printf "  %-55s %10s\n" "$name" "$human_size"
    total_closure=$((total_closure + size))
done <<< "$sorted_paths"

echo ""
total_human=$(numfmt --to=iec-i --suffix=B "$total_closure" 2>/dev/null || echo "${total_closure}B")
echo "Total GNOME closure overhead: $total_human (overlapping deps counted multiple times)"
echo ""

echo "--- Why each is pulled in ---"
echo ""
while read -r line; do
    path=$(echo "$line" | sed 's/\t.*//' | xargs)
    name=$(basename "$path" | sed 's/^[a-z0-9]\{32\}-//')
    echo ">> $name"
    nix why-depends "$target" "$path" 2>/dev/null | tail -n +2 | sed 's/\x1b\[[0-9;]*m//g' || true
    echo ""
done <<< "$sorted_paths"
