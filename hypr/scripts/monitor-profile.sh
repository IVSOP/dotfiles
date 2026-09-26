#!/usr/bin/env bash
set -euo pipefail

config_dir="$HOME/.config/hypr/monitor-profiles"
hypr_config="$HOME/.config/hypr/hyprland.lua"
runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/hypr-monitor-ui
session_running() {
    [[ -f $runtime/session.pid ]] &&
        kill -0 "$(cat "$runtime/session.pid")" 2>/dev/null
}
ensure_session() {
    mkdir -p "$runtime"
    if ! session_running; then
        nohup "$HOME/.config/hypr/scripts/monitor-session.sh" \
            >"$runtime/session.log" 2>&1 </dev/null &
    fi
}

case ${1:-} in
    apply|select)
        if [[ $# != 2 || ! $2 =~ ^[a-zA-Z0-9._-]+$ ]]; then
            printf 'Usage: %s apply PROFILE\n' "$0" >&2
            exit 2
        fi
        name=$2
        # Keep the old spelling working after adopting hyprmoncfg's filename slug.
        if [[ $name == d2_1080 ]]; then name=d2-1080; fi
        profile_path="$config_dir/profiles/$name.json"
        if [[ ! -f $profile_path ]] ||
            ! jq -e --arg name "$name" '.name == $name' "$profile_path" >/dev/null; then
            printf 'Unknown profile: %s\n' "$name" >&2
            exit 1
        fi

        monitors=$(hyprctl -j monitors all)
        if ! jq -e --slurpfile profile "$profile_path" '
            def hardware_key: [.make, .model, .serial] |
                map(select(. != null and . != "")) | join("|");
            [.[] | hardware_key] as $connected |
            any($profile[0].outputs[];
                .enabled and (.match_key as $key | $connected | index($key) != null))
        ' <<<"$monitors" >/dev/null; then
            printf 'No enabled output from profile %s is connected\n' "$name" >&2
            exit 1
        fi

        mkdir -p "$runtime"
        previous_selection=$(mktemp "$runtime/previous-selection.XXXXXX")
        had_previous=false
        if [[ -f $runtime/manual-profile ]]; then
            cp "$runtime/manual-profile" "$previous_selection"
            had_previous=true
        fi
        committed=false
        result=""
        restore_on_exit() {
            if [[ -n $result ]]; then command rm -f "$result"; fi
            if [[ $committed == true ]]; then
                command rm -f "$previous_selection"
            elif [[ $had_previous == true ]]; then
                mv -f "$previous_selection" "$runtime/manual-profile"
            else
                command rm -f "$previous_selection" "$runtime/manual-profile"
            fi
        }
        trap restore_on_exit EXIT
        hardware=$(jq -c '[.[] | [.make, .model, .serial]] | sort' <<<"$monitors")
        temp=$(mktemp "$runtime/manual-profile.XXXXXX")
        printf '%s\n%s\n' "$name" "$hardware" >"$temp"
        mv -f "$temp" "$runtime/manual-profile"

        ensure_session
        ready=false
        for ((attempt=0; attempt<50; attempt++)); do
            if [[ $(cat "$runtime/daemon-mode" 2>/dev/null || true) == manual ]]; then
                ready=true
                break
            fi
            sleep 0.2
        done
        if [[ $ready != true ]]; then
            printf 'Monitor session did not pause automatic selection\n' >&2
            exit 1
        fi

        result=$(mktemp "$runtime/apply-result.XXXXXX")
        set +e
        hyprmoncfg --config-dir "$config_dir" --hypr-config "$hypr_config" \
            apply "$name" | tee "$result"
        status=${PIPESTATUS[0]}
        set -e
        if [[ $status != 0 ]] || ! grep -Fq 'Configuration kept' "$result"; then
            exit 1
        fi
        committed=true
        ;;
    auto)
        command rm -f "$runtime/manual-profile"
        ensure_session
        for ((attempt=0; attempt<50; attempt++)); do
            if [[ $(cat "$runtime/daemon-mode" 2>/dev/null || true) == auto ]]; then
                printf 'Automatic profile selection restored\n'
                exit 0
            fi
            sleep 0.2
        done
        printf 'Monitor session did not resume automatic selection\n' >&2
        exit 1
        ;;
    mode)
        if [[ -f $runtime/manual-profile ]]; then
            sed -n '1p' "$runtime/manual-profile"
        else
            printf 'auto\n'
        fi
        ;;
    *)
        exec hyprmoncfg --config-dir "$config_dir" --hypr-config "$hypr_config" "$@"
        ;;
esac
