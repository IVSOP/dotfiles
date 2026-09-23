#!/usr/bin/env bash
set -euo pipefail

runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/waybar
mkdir -p "$runtime"

monitor=""
if command -v swaymsg >/dev/null 2>&1; then
    monitor=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '
        [.[] | select(.active == true)] |
        ([.[] | select(.focused == true)][0] // .[0]).name // empty
    ' 2>/dev/null || true)
fi
[[ $monitor =~ ^[a-zA-Z0-9._-]+$ ]] || monitor=eDP-1

read_script="$HOME/Desktop/Rofi-Themer/Scripts/read.sh"
mapfile -t themes < <("$read_script" waybar 2>/dev/null || true)
resolve_theme() {
    local path=$1 fallback=$2
    if [[ $path = /* && -f $path ]]; then
        printf '%s\n' "$path"
    elif [[ -f $HOME/$path ]]; then
        printf '%s\n' "$HOME/$path"
    else
        printf '%s\n' "$fallback"
    fi
}
source_config=$(resolve_theme "${themes[0]:-}" "$HOME/.config/waybar/config.jsonc")
source_style=$(resolve_theme "${themes[1]:-}" "$HOME/.config/waybar/style.css")

changed=false
temp=$(mktemp "$runtime/config.jsonc.XXXXXX")
sed "s/MONITOR_NAME/$monitor/g" "$source_config" >"$temp"
if ! cmp -s "$temp" "$runtime/config.jsonc"; then
    mv -f "$temp" "$runtime/config.jsonc"
    changed=true
else
    command rm "$temp"
fi
temp=$(mktemp "$runtime/style.css.XXXXXX")
cp "$source_style" "$temp"
if ! cmp -s "$temp" "$runtime/style.css"; then
    mv -f "$temp" "$runtime/style.css"
    changed=true
else
    command rm "$temp"
fi

running_waybar=$(pgrep -af '^waybar([[:space:]]|$)' || true)
if [[ -n $running_waybar ]]; then
    if [[ $changed == true ]]; then
        while read -r pid command; do
            if [[ $command == *"$runtime/config.jsonc"* ]]; then
                kill -USR2 "$pid" || true
            fi
        done <<<"$running_waybar"
    fi
else
    waybar -c "$runtime/config.jsonc" -s "$runtime/style.css" \
        >"$runtime/waybar.log" 2>&1 &
fi
