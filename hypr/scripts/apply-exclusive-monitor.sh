#!/usr/bin/env bash
set -euo pipefail

identity=${1:?A primary monitor selector is required}
monitors=$(hyprctl -j monitors all)
allowed=()
for selector in "$@"; do
    output=$(jq -r --arg identity "$selector" '
        def hardware_key: [.make, .model, .serial] |
            map(select(. != null and . != "")) | join("|");
        [.[] | select((.name == $identity or hardware_key == $identity or .serial == $identity)
            and .disabled == false) | .name][0] // empty
    ' <<<"$monitors")
    if [[ ! $output =~ ^[a-zA-Z0-9._-]+$ ]]; then
        printf 'No active monitor matching %s\n' "$selector" >&2
        exit 1
    fi
    allowed+=("$output")
done

# hyprmoncfg 1.9.1 configures saved outputs; an extra connected display is
# otherwise left as it was. Keep only the listed outputs active.
allowed_json=$(jq -n '$ARGS.positional' --args "${allowed[@]}")
while IFS= read -r output; do
    if [[ $output =~ ^[a-zA-Z0-9._-]+$ ]]; then
        hyprctl eval "hl.monitor({ output = \"$output\", disabled = true })"
    fi
done < <(jq -r --argjson allowed "$allowed_json" '
    .[] | select(.disabled == false and (.name as $name | $allowed | index($name) == null)) | .name
' <<<"$monitors")

exec "$HOME/.config/hypr/scripts/apply-monitor-ui.sh" "$identity"
