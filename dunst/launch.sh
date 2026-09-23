#!/usr/bin/env bash
set -euo pipefail

"$HOME/.config/dunst/get-theme.sh"
runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}/dunst
dropins=("$HOME"/.config/dunst/dunstrc.d/*.conf)

if ! dunstctl debug >/dev/null 2>&1; then
    dunst -conf "$runtime/dunstrc" >"$runtime/dunst.log" 2>&1 &
fi

# Reload the generated theme and the original drop-ins without replacing the
# running notification daemon.
for attempt in 1 2 3 4 5; do
    if dunstctl reload "$runtime/dunstrc" "${dropins[@]}" \
        >>"$runtime/dunst.log" 2>&1; then
        exit 0
    fi
    sleep 0.2
done
exit 1
