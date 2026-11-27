#!/usr/bin/env bash
set -euo pipefail

action=$1
bar_pid=${2:-$PPID}
unit="waybar-keep-awake-$bar_pid.service"

if [[ $action == acquire ]]; then
    # Preserve the service notification address across systemd-inhibit.
    exec systemd-inhibit --what=idle --mode=block --who=Waybar \
        --why='Keep-awake mode' -- "$BASH" "$0" hold "$bar_pid" "${NOTIFY_SOCKET:?}"
fi

if [[ $action == hold ]]; then
    # systemd-inhibit runs this only after logind grants the lock.
    NOTIFY_SOCKET=$3 systemd-notify --ready
    exec tail --pid="$bar_pid" -f /dev/null
fi

active_unit() {
    systemctl --user list-units --state=active --plain --no-legend --no-pager "$unit"
}

notify() {
    notify-send --app-name=Waybar --transient \
        --hint=string:x-canonical-private-synchronous:waybar-keep-awake "$@"
}

if [[ $action == status ]]; then
    if ! active=$(active_unit); then
        printf '%s\n' '{"alt":"unavailable","tooltip":"Keep-awake status unavailable"}'
    elif [[ -n $active ]]; then
        printf '%s\n' '{"alt":"awake","tooltip":"Keep awake is on. Click to restore idle timers."}'
    else
        printf '%s\n' '{"alt":"idle","tooltip":"Keep awake is off. Click to pause idle timers."}'
    fi
    exit
fi

[[ $action == toggle ]] || exit 2

runtime=${XDG_RUNTIME_DIR:?}/waybar
mkdir -p "$runtime"
exec 9>"$runtime/keep-awake.lock"
flock 9

if ! active=$(active_unit); then
    notify --icon=dialog-warning-symbolic 'Keep-awake status unavailable'
    exit 1
fi

if [[ -n $active ]]; then
    if ! systemctl --user stop "$unit"; then
        notify --icon=dialog-warning-symbolic 'Could not turn keep-awake mode off'
        exit 1
    fi
    icon=weather-clear-night-symbolic
    title='Keep awake is off'
    body='Normal idle timers are active.'
else
    if ! systemd-run --user --quiet --collect --unit="$unit" --service-type=notify \
        --property=NotifyAccess=all --property=TimeoutStartSec=5s \
        -- "$BASH" "$0" acquire "$bar_pid" 9>&-; then
        notify --icon=dialog-warning-symbolic 'Could not turn keep-awake mode on'
        exit 1
    fi
    icon=weather-clear-symbolic
    title='Keep awake is on'
    body='Automatic locking, screen blanking, and idle suspend are paused.'
fi

kill -s RTMIN+10 "$bar_pid"
notify --icon="$icon" "$title" "$body"
