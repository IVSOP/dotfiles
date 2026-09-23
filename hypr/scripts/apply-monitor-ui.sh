#!/usr/bin/env bash
set -euo pipefail

runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/hypr-monitor-ui
mkdir -p "$runtime"
exec 9>"$runtime/lock"
if ! flock -w 15 9; then
    printf 'Timed out waiting to update monitor UI\n' >&2
    exit 1
fi

if [[ $# -gt 0 ]]; then
    printf '%s\n' "$1" >"$runtime/primary-identity"
fi
identity=$(cat "$runtime/primary-identity" 2>/dev/null || true)
if [[ -z $identity ]]; then
    identity=$(jq -r '.outputs[] | select(.enabled) | .match_key' \
        "$HOME/.config/hypr/monitor-profiles/profiles/ld1.json" | head -n 1)
fi
monitors=$(hyprctl -j monitors all)
active_outputs=$(jq -c '[.[] | select(.disabled == false) | .name] | sort' <<<"$monitors")
connector=$(jq -r --arg identity "$identity" '
    def hardware_key: [.make, .model, .serial] |
        map(select(. != null and . != "")) | join("|");
    [.[] | select((.name == $identity or hardware_key == $identity or .serial == $identity)
        and .disabled == false) | .name][0] //
    [.[] | select(.disabled == false) | .name][0] // empty
' <<<"$monitors")
if [[ ! $connector =~ ^[a-zA-Z0-9._-]+$ ]]; then
    printf 'No active monitor found for the UI\n' >&2
    exit 1
fi

read_script="$HOME/Desktop/Rofi-Themer/Scripts/read.sh"
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

mapfile -t bar_themes < <("$read_script" waybar 2>/dev/null || true)
dunst_theme=$("$read_script" dunst 2>/dev/null || true)
bar_config_fallback="$HOME/.config/waybar/config.jsonc"
bar_style_fallback="$HOME/.config/waybar/style.css"
dunst_config_fallback="$HOME/.config/dunst/dunstrc"
[[ -f $bar_config_fallback ]] || bar_config_fallback="$HOME/.config/waybar/themes/blue.jsonc"
[[ -f $bar_style_fallback ]] || bar_style_fallback="$HOME/.config/waybar/themes/blue.css"
[[ -f $dunst_config_fallback ]] || dunst_config_fallback="$HOME/.config/dunst/themes/dunstrc-blue"
bar_config=$(resolve_theme "${bar_themes[0]:-}" "$bar_config_fallback")
bar_style=$(resolve_theme "${bar_themes[1]:-}" "$bar_style_fallback")
dunst_config=$(resolve_theme "$dunst_theme" "$dunst_config_fallback")

update_file() {
    local target=$1 temp=$2
    if [[ -f $target ]] && cmp -s "$temp" "$target"; then
        command rm "$temp"
        return 1
    fi
    mv -f "$temp" "$target"
}

bar_changed=false
temp=$(mktemp "$runtime/waybar.jsonc.XXXXXX")
sed "s/MONITOR_NAME/$connector/g" "$bar_config" >"$temp"
if update_file "$runtime/waybar.jsonc" "$temp"; then bar_changed=true; fi
temp=$(mktemp "$runtime/style.css.XXXXXX")
cp "$bar_style" "$temp"
if update_file "$runtime/style.css" "$temp"; then bar_changed=true; fi
target_state="v3 $connector $active_outputs"
target_changed=false
if [[ $(cat "$runtime/waybar-target-state" 2>/dev/null || true) != "$target_state" ]]; then
    target_changed=true
fi

record_waybar_update() {
    printf '%s\n' "$target_state" >"$runtime/waybar-target-state"
    command rm -f "$runtime/waybar-retry-pending" "$runtime/waybar-active-outputs"
    printf '%(%F %T)T Waybar %s: %s (active: %s)\n' \
        -1 "$1" "$connector" "$active_outputs" >>"$runtime/ui.log"
}

start_waybar() {
    waybar -c "$runtime/waybar.jsonc" -s "$runtime/style.css" 9>&- \
        >>"$runtime/waybar.log" 2>&1 &
    record_waybar_update "$1"
}

dunst_changed=false
temp=$(mktemp "$runtime/dunstrc.XXXXXX")
sed "s/MONITOR_NAME/$connector/g" "$dunst_config" >"$temp"
if update_file "$runtime/dunstrc" "$temp"; then dunst_changed=true; fi

running_waybar=$(pgrep -af '^waybar([[:space:]]|$)' || true)
owned_waybar=()
if [[ -n $running_waybar ]]; then
    while read -r pid command; do
        if [[ $command == *"$runtime/waybar.jsonc"* ]]; then
            owned_waybar+=("$pid")
        fi
    done <<<"$running_waybar"
fi

if [[ ${#owned_waybar[@]} -eq 0 ]]; then
    start_waybar start
elif [[ $target_changed == true ]]; then
    for pid in "${owned_waybar[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
    for ((attempt=0; attempt<10; attempt++)); do
        still_running=false
        for pid in "${owned_waybar[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then still_running=true; fi
        done
        if [[ $still_running == false ]]; then break; fi
        sleep 0.1
    done
    for pid in "${owned_waybar[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then kill -KILL "$pid" 2>/dev/null || true; fi
    done
    start_waybar restart
elif [[ $bar_changed == true ]]; then
    for pid in "${owned_waybar[@]}"; do
        if kill -USR2 "$pid"; then record_waybar_update reload; fi
    done
fi

if ! dunstctl debug >/dev/null 2>&1; then
    dunst -conf "$runtime/dunstrc" 9>&- >"$runtime/dunst.log" 2>&1 &
    dunst_changed=true
fi
if [[ $dunst_changed == true ]]; then
    : >"$runtime/dunst-reload-pending"
fi
if [[ -f $runtime/dunst-reload-pending ]]; then
    dropins=("$HOME"/.config/dunst/dunstrc.d/*.conf)
    if dunstctl reload "$runtime/dunstrc" "${dropins[@]}" \
        >>"$runtime/dunst.log" 2>&1; then
        command rm "$runtime/dunst-reload-pending"
    fi
fi
