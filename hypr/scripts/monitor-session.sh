#!/usr/bin/env bash
set -euo pipefail

runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/hypr-monitor-ui
mkdir -p "$runtime"
exec 9>"$runtime/session.lock"
flock -n 9 || exit 0
printf '%s\n' "$$" >"$runtime/session.pid"
printf '%s\n' 2 >"$runtime/session-version"
command rm -f "$runtime/daemon-mode"

daemon_pid=""
daemon_mode=""
stop_daemon() {
    if [[ -n $daemon_pid ]]; then
        kill -TERM "$daemon_pid" 2>/dev/null || true
        wait "$daemon_pid" 2>/dev/null || true
        daemon_pid=""
    fi
}
start_daemon() {
    if ! command -v hyprmoncfgd >/dev/null 2>&1; then
        printf 'hyprmoncfgd is not installed yet\n' >&2
        return
    fi
    hyprmoncfgd \
        --config-dir "$HOME/.config/hypr/monitor-profiles" \
        --hypr-config "$HOME/.config/hypr/hyprland.lua" \
        9>&- >"$runtime/hyprmoncfgd.log" 2>&1 &
    daemon_pid=$!
}
cleanup() {
    stop_daemon
    command rm -f "$runtime/session.pid" "$runtime/session-version" "$runtime/daemon-mode"
}
trap cleanup EXIT
trap 'exit 0' INT TERM

# The theme daemon may still be starting. Each pass retries its queries and
# the first pass creates the runtime files before Waybar or Dunst start.
while :; do
    # The helper uses a nonblocking lock: an interactive mirror command must
    # be able to wait for this loop to acknowledge that the daemon is stopped.
    python3 "$HOME/.config/hypr/scripts/monitor-mirror.py" check \
        9>&- 2>>"$runtime/session.log" || true
    desired_mode=auto
    if [[ -f $runtime/mirror.json ]]; then
        desired_mode=mirror
    elif [[ -f $runtime/paused ]]; then
        desired_mode=paused
    elif [[ -f $runtime/manual-profile ]]; then
        saved_hardware=$(sed -n '2p' "$runtime/manual-profile")
        current_hardware=$(hyprctl -j monitors all 2>/dev/null |
            jq -c '[.[] | [.make, .model, .serial]] | sort' 2>/dev/null || true)
        if [[ -n $current_hardware && $current_hardware != "$saved_hardware" ]]; then
            command rm -f "$runtime/manual-profile"
        else
            desired_mode=manual
        fi
    fi
    if [[ $desired_mode != "$daemon_mode" ]]; then
        stop_daemon
        if [[ $desired_mode == auto ]]; then start_daemon; fi
        daemon_mode=$desired_mode
        printf '%s\n' "$daemon_mode" >"$runtime/daemon-mode"
    elif [[ $daemon_mode == auto ]]; then
        if [[ -z $daemon_pid ]] || ! kill -0 "$daemon_pid" 2>/dev/null; then
            if [[ -n $daemon_pid ]]; then wait "$daemon_pid" 2>/dev/null || true; fi
            daemon_pid=""
            start_daemon
        fi
    fi
    "$HOME/.config/hypr/scripts/apply-monitor-ui.sh" 9>&- 2>>"$runtime/ui.log" || true
    sleep 2
done
