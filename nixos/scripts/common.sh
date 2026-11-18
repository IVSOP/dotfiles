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
    case "${target,,}" in
        ivx13) target=ivX13 ;;
        ivpc) target=IVPC ;;
        server) target=server ;;
        *)
            printf 'Unsupported target: %s. Choose ivX13, IVPC, or server.\n' "$target" >&2
            exit 1
            ;;
    esac
}

sync_configuration() {
    printf 'Copying configuration from %s to /etc/nixos\n' "$config_dir"
    sudo install -d -m 0755 /etc/nixos
    sudo rsync -rp --delay-updates --chmod=D755,F644 -- \
        "$config_dir/flake.nix" "$config_dir/flake.lock" \
        "$config_dir/pins.nix" "$config_dir/sources.json" "$config_dir/trusted-ssh-keys.nix" \
        "$config_dir/hosts" "$config_dir/profiles" "$config_dir/modules" "$config_dir/images" \
        /etc/nixos/
}
