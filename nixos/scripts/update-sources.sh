#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"

# These sources use release assets or individual firmware files rather than
# flake inputs. Keep them reproducible, but refresh them on every update.sh run.
pending=$(mktemp "$config_dir/.sources.json.XXXXXX")
trap 'rm -f -- "$pending" "$pending.next"' EXIT
cp -- "$config_dir/sources.json" "$pending"

github() {
    curl --fail --silent --show-error --location --retry 2 \
        --connect-timeout 15 --max-time 60 \
        -H 'Accept: application/vnd.github+json' \
        "https://api.github.com/repos/$1"
}

prefetch_hash() {
    nix store prefetch-file --json --hash-type sha256 "$1" | jq -er '.hash'
}

mapfile -t plugins < <(jq -r '.obsidianPlugins | keys[]' "$pending")
for id in "${plugins[@]}"; do
    repo=$(jq -r --arg id "$id" '.obsidianPlugins[$id].repo' "$pending")
    current=$(jq -r --arg id "$id" '.obsidianPlugins[$id].version' "$pending")
    release=$(github "$repo/releases/latest")
    version=$(jq -er '.tag_name | select(type == "string" and length > 0)' <<< "$release")
    if [[ $version == "$current" ]]; then
        printf 'Obsidian %s: %s (current)\n' "$id" "$version"
        continue
    fi

    hashes='{}'
    for name in main.js manifest.json styles.css; do
        url=$(jq -r --arg name "$name" \
            '[.assets[] | select(.name == $name) | .browser_download_url][0] // empty' <<< "$release")
        if [[ -z $url ]]; then
            [[ $name == styles.css ]] && continue
            printf 'Missing required asset %s in %s release %s\n' "$name" "$repo" "$version" >&2
            exit 1
        fi
        hash=$(prefetch_hash "$url")
        hashes=$(jq --arg name "$name" --arg hash "$hash" '. + {($name): $hash}' <<< "$hashes")
    done
    jq --arg id "$id" --arg version "$version" --argjson hashes "$hashes" \
        '.obsidianPlugins[$id] |= (.version = $version | .hashes = $hashes)' \
        "$pending" > "$pending.next"
    mv -- "$pending.next" "$pending"
    printf 'Obsidian %s: %s -> %s\n' "$id" "$current" "$version"
done

repo=$(jq -r '.radxaFirmware.repo' "$pending")
current=$(jq -r '.radxaFirmware.revision' "$pending")
revision=$(github "$repo/commits?per_page=1" | jq -er '.[0].sha | select(test("^[0-9a-f]{40}$"))')
if [[ $revision != "$current" ]]; then
    count=$(jq '.radxaFirmware.files | length' "$pending")
    for ((i = 0; i < count; i++)); do
        directory=$(jq -r --argjson i "$i" '.radxaFirmware.files[$i].directory' "$pending")
        name=$(jq -r --argjson i "$i" '.radxaFirmware.files[$i].name' "$pending")
        hash=$(prefetch_hash "https://raw.githubusercontent.com/$repo/$revision/radxa-firmware/lib/firmware/$directory/$name")
        jq --argjson i "$i" --arg hash "$hash" '.radxaFirmware.files[$i].hash = $hash' \
            "$pending" > "$pending.next"
        mv -- "$pending.next" "$pending"
    done
    jq --arg revision "$revision" '.radxaFirmware.revision = $revision' \
        "$pending" > "$pending.next"
    mv -- "$pending.next" "$pending"
    printf 'Radxa firmware: %.12s -> %.12s\n' "$current" "$revision"
else
    printf 'Radxa firmware: %.12s (current)\n' "$current"
fi

# A failed lookup or download leaves the original source lock intact.
if ! cmp -s -- "$pending" "$config_dir/sources.json"; then
    chmod 0644 "$pending"
    mv -- "$pending" "$config_dir/sources.json"
fi
