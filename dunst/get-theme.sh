#!/usr/bin/env bash
set -euo pipefail

runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/dunst
mkdir -p "$runtime"

monitor=""
if [[ -n ${SWAYSOCK:-} ]] && command -v swaymsg >/dev/null 2>&1; then
    monitor=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '
        [.[] | select(.active == true)] |
        ([.[] | select(.focused == true)][0] // .[0]).name // empty
    ' 2>/dev/null || true)
elif command -v xrandr >/dev/null 2>&1; then
    monitor=$(xrandr --query 2>/dev/null | awk '
        / connected primary / { print $1; found = 1; exit }
        / connected/ && first == "" { first = $1 }
        END { if (!found && first != "") print first }
    ' || true)
fi
[[ $monitor =~ ^[a-zA-Z0-9._-]+$ ]] || monitor=0

source_path=$("$HOME/Desktop/Rofi-Themer/Scripts/read.sh" dunst 2>/dev/null || true)
if [[ $source_path = /* && -f $source_path ]]; then
    source_config=$source_path
elif [[ -f $HOME/$source_path ]]; then
    source_config=$HOME/$source_path
else
    source_config=$HOME/.config/dunst/dunstrc
fi

temp=$(mktemp "$runtime/dunstrc.XXXXXX")
sed "s/MONITOR_NAME/$monitor/g" "$source_config" >"$temp"
if ! cmp -s "$temp" "$runtime/dunstrc"; then
    mv -f "$temp" "$runtime/dunstrc"
else
    command rm "$temp"
fi
