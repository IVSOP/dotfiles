#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h || ${1:-} == help ]]; then
    cat <<'HELP'
Usage: monitor COMMAND [ARGS]

  pause | stop       Pause automatic management without changing the layout.
                     Stays paused when displays are connected or disconnected.
  resume | start     Resume automatic profile selection (same as auto).
  mirror             Pick the screen to copy, then the screen showing its copy.
                     Pauses management and keeps the source screen's settings.
  unmirror           Restore the receiver's layout and prior management mode.
                     Also happens automatically if either screen disconnects.
  mode               Show auto, paused, mirror, or the selected profile name.
  apply PROFILE      Apply a saved profile with a confirmation/revert prompt.
                     Holds it until connected displays change or you resume.
  profiles           List saved profiles.
  save NAME          Save the current layout as a profile.
  tui                Open the profile editor (also the default without args).
  --help             Show this help.

Mirror layouts are temporary; saved profiles are not changed. Unplugging the
receiver leaves the source working. If the source disappears, a remaining
display is kept usable. Resume and apply also end a temporary mirror session.
Other commands and arguments are passed through to hyprmoncfg.
HELP
    exit 0
fi

config_dir="$HOME/.config/hypr/monitor-profiles"
hypr_config="$HOME/.config/hypr/hyprland.lua"
runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/hypr-monitor-ui
scripts="$HOME/.config/hypr/scripts"
mkdir -p "$runtime"
# Serialize user commands, but let the session's disconnect watcher run.
exec 8>"$runtime/command.lock"
flock -w 15 8 || { printf 'Another monitor command is still running\n' >&2; exit 1; }
session_running() {
    [[ -f $runtime/session.pid ]] &&
        kill -0 "$(cat "$runtime/session.pid")" 2>/dev/null
}
ensure_session() {
    mkdir -p "$runtime"
    # Replace the old loop once so new commands work in an existing login.
    if session_running && [[ $(cat "$runtime/session-version" 2>/dev/null || true) != 2 ]]; then
        local previous_manual
        previous_manual=$(cat "$runtime/manual-profile" 2>/dev/null || true)
        kill -TERM "$(cat "$runtime/session.pid")"
        for ((attempt=0; attempt<50; attempt++)); do
            if ! session_running; then break; fi
            sleep 0.2
        done
        if session_running; then
            printf 'Old monitor session did not stop\n' >&2
            exit 1
        fi
        if [[ -n $previous_manual ]]; then
            printf '%s\n' "$previous_manual" >"$runtime/manual-profile"
        fi
    fi
    if ! session_running; then
        nohup "$HOME/.config/hypr/scripts/monitor-session.sh" \
            8>&- >"$runtime/session.log" 2>&1 </dev/null &
    fi
}
wait_mode() {
    for ((attempt=0; attempt<75; attempt++)); do
        if [[ $(cat "$runtime/daemon-mode" 2>/dev/null || true) == "$1" ]]; then
            return 0
        fi
        sleep 0.2
    done
    printf 'Monitor session did not enter %s mode; see %s/session.log\n' "$1" "$runtime" >&2
    return 1
}
unmirror() {
    python3 "$scripts/monitor-mirror.py" stop
}

case ${1:-} in
    pause|stop)
        : >"$runtime/paused"
        ensure_session
        if [[ -f $runtime/mirror.json ]]; then wait_mode mirror; else wait_mode paused; fi
        printf 'Automatic monitor management paused\n'
        ;;
    mirror)
        ensure_session
        python3 "$scripts/monitor-mirror.py" start
        ;;
    unmirror)
        unmirror
        ;;
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
            # hyprmoncfg normalizes saved match keys to lowercase.
            def hardware_key: [.make, .model, .serial] |
                map(select(. != null and . != "")) | join("|") | ascii_downcase;
            [.[] | hardware_key] as $connected |
            any($profile[0].outputs[];
                .enabled and ((.match_key | ascii_downcase) as $key |
                    $connected | index($key) != null))
        ' <<<"$monitors" >/dev/null; then
            printf 'No enabled output from profile %s is connected\n' "$name" >&2
            exit 1
        fi

        unmirror
        ensure_session
        mkdir -p "$runtime"
        previous_selection=$(mktemp "$runtime/previous-selection.XXXXXX")
        had_previous=false
        if [[ -f $runtime/manual-profile ]]; then
            cp "$runtime/manual-profile" "$previous_selection"
            had_previous=true
        fi
        committed=false
        result=""
        was_paused=false
        if [[ -f $runtime/paused ]]; then was_paused=true; fi
        restore_on_exit() {
            if [[ -n $result ]]; then command rm -f "$result"; fi
            if [[ $committed == true ]]; then
                command rm -f "$previous_selection"
            elif [[ $had_previous == true ]]; then
                mv -f "$previous_selection" "$runtime/manual-profile"
            else
                command rm -f "$previous_selection" "$runtime/manual-profile"
            fi
            if [[ $committed != true && $was_paused == true ]]; then : >"$runtime/paused"; fi
        }
        trap restore_on_exit EXIT
        hardware=$(jq -c '[.[] | [.make, .model, .serial]] | sort' <<<"$monitors")
        temp=$(mktemp "$runtime/manual-profile.XXXXXX")
        printf '%s\n%s\n' "$name" "$hardware" >"$temp"
        mv -f "$temp" "$runtime/manual-profile"
        command rm -f "$runtime/paused"

        wait_mode manual

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
    auto|resume|start)
        unmirror
        command rm -f "$runtime/manual-profile" "$runtime/paused"
        ensure_session
        wait_mode auto
        printf 'Automatic profile selection restored\n'
        ;;
    mode)
        if [[ -f $runtime/mirror.json ]]; then
            printf 'mirror\n'
        elif [[ -f $runtime/paused ]]; then
            printf 'paused\n'
        elif [[ -f $runtime/manual-profile ]]; then
            sed -n '1p' "$runtime/manual-profile"
        else
            printf 'auto\n'
        fi
        ;;
    *)
        exec hyprmoncfg --config-dir "$config_dir" --hypr-config "$hypr_config" "$@"
        ;;
esac
