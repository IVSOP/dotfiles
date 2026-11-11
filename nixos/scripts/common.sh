#!/usr/bin/env bash

# Shared by the maintenance scripts in the configuration directory.
config_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

select_target() {
    if [[ $# -gt 1 ]]; then
        printf 'Usage: %s [ivX13|IVPC|server]\n' "${0##*/}" >&2
        exit 1
    fi
    if [[ ${1:-} == --help || ${1:-} == -h ]]; then
        printf 'Usage: %s [ivX13|IVPC|server]\nDefaults to the current hostname.\n' "${0##*/}"
        exit 0
    fi

    target="${1:-$(hostname -s)}"
    case "$target" in
        ivX13|IVPC|server) ;;
        *)
            printf 'Unsupported target: %s. Choose ivX13, IVPC, or server.\n' "$target" >&2
            exit 1
            ;;
    esac
}

sync_configuration() {
    printf 'Copying configuration from %s to /etc/nixos\n' "$config_dir"
    sudo install -d -m 0755 /etc/nixos
    # All x86 modules live at the top level; leave radxa/ out for now.
    sudo install -m 0644 -- "$config_dir"/*.nix "$config_dir/flake.lock" "$config_dir/sources.json" /etc/nixos/
}
