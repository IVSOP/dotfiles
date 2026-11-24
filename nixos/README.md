# NixOS machines

This configuration manages four separate machines:

| Machine | Hostname / flake target | Architecture | User | Machine configuration |
| --- | --- | --- | --- | --- |
| Laptop | `ivX13` | `x86_64-linux` | `ivsopi3` | [hosts/ivX13](hosts/ivX13/default.nix) |
| Desktop | `IVPC` | `x86_64-linux` | `ivsopi3` | [hosts/IVPC](hosts/IVPC/default.nix) |
| Server | `server` | `x86_64-linux` | `ivsopi3` | [hosts/server](hosts/server/default.nix) |
| Radxa server (ROCK 4C+) | `rock-server` | `aarch64-linux` | `radxa` | [hosts/rock-server](hosts/rock-server/default.nix) |

For a fresh laptop, desktop, or x86 server install, start with the
[simple installation guide](INSTALL.md). It covers disk preparation with optional
LUKS encryption and installation from files copied into `/mnt/etc/nixos`.

The server and Radxa server have separate configurations and setup procedures:

- [Server setup](SERVER.md): the x86 server, installed with `nixos-install`.
- [Radxa server setup](radxa/SERVER.md): the ARM board, flashed with a bootable SD card image.
- [Radxa kernel audit](radxa/SERVER-KERNEL-AUDIT.md): board and kernel support details.

## Configuration layout

[flake.nix](flake.nix) defines the four host targets and the image outputs.
Start with `hosts/<hostname>/default.nix` to see a machine's imports, settings,
and hardware configuration.

- `profiles/` groups settings used together. The three installed x86 hosts
  share the [x86 base](profiles/x86-base.nix). The desktop and laptop also
  import the [workstation profile](profiles/workstation/default.nix) for
  Hyprland, desktop apps, and services started on demand.
- `modules/` holds features that can be selected independently. All three
  installed x86 hosts explicitly import [development](modules/development.nix)
  and [dotfile links](modules/dotfiles.nix).
  All four hosts share [Docker logging](modules/docker-logging.nix) and read
  authorized public keys from [trusted-ssh-keys.nix](trusted-ssh-keys.nix).
- `images/` configures the [PC installer](images/pc-installer.nix) and
  [Radxa SD image](images/rock-server.nix). The Radxa image imports the board's
  host configuration and adds image provisioning. The three x86 hosts and
  PC installer share [Bootvine](modules/bootvine.nix) for boot, LUKS prompts,
  and shutdown.

## Rebuild an installed x86 machine

Edit the files in this repository, then run these scripts as your normal user
(they call `sudo` where needed):

```sh
# Copy the configuration to /etc/nixos and switch to it
./rebuild.sh

# Update inputs and sources, rebuild, then update Rust toolchains
./update.sh

# Copy the configuration, collect garbage, delete old generations,
# and rebuild the boot configuration
./gc.sh
```

Each script works from any directory and selects `ivX13`, `IVPC`, or `server`
from the local short hostname, ignoring case. An optional argument such as
`./rebuild.sh IVPC` selects which configuration to apply to the local machine.

All three copy the flake, shared data files, and the `hosts/`, `profiles/`,
`modules/`, and `images/` trees to `/etc/nixos` before rebuilding with
`--flake path:/etc/nixos#TARGET`. The copy includes new files before they are
tracked in Git and preserves existing unrelated files in `/etc/nixos`.

`gc.sh` runs `sudo nix-store --gc`, `sudo nix-collect-garbage -d`, and then
`sudo nixos-rebuild boot`. It deletes old generations and updates the boot
configuration without switching the running system. Scripts stop if a command
fails.

`update.sh` updates all inputs except those fixed to commits in `flake.nix`.
The manual pins are Hyprland and its portal, hy3, Solana CLI, Anchor, the SBF
builder and platform tools, and Tracy. Lanzaboote, VS Code extensions,
Bootvine, and Codex update normally. Waybar uses the package from the main
nixpkgs input.

NixOS installs Rustup. Plain `cargo` and `rustc` follow the project’s
`rust-toolchain.toml` and default to stable elsewhere. Rustup installs missing
project toolchains on first use. After a successful rebuild, `./update.sh`
refreshes stable and nightly in the invoking user’s Rustup home with the
configured components and cross-compilation targets.

Codex uses the regular nixpkgs package on the three x86 hosts and PC installer
ISO, taken from the branch-tracking `nixpkgs-codex` master input so releases can
arrive before nixos-unstable. `update.sh` updates it normally, without a manual
Codex version pin. Bootvine uses the built-in NixOS module and package from the
system's nixpkgs input. Cached packages are downloaded when available.

The warning table shows the selected versions and revisions and where to update
them manually. Package pins live in [pins.nix](pins.nix); fixed flake inputs live
in `flake.nix` and `flake.lock`. Check upstream releases and update these pins
and associated hashes manually. The table is a reminder, not an automatic check
for new releases. Run `./scripts/pins.sh` to see it without updating or rebuilding.

Obsidian plugins and Radxa wireless firmware are tracked in [sources.json](sources.json).
`./scripts/update-sources.sh` refreshes plugin releases, the upstream firmware
revision, and their hashes; `update.sh` runs it automatically before rebuilding.
A lookup or download failure leaves `sources.json` unchanged and stops the rebuild.
Plugin enable/disable settings are preserved. This also updates the source lock
for the next Radxa image build, without enabling Bootvine on the board.

For the Radxa server, follow the [image build and deployment guide](radxa/SERVER.md).
The `packages.x86_64-linux.server-image` and
`packages.aarch64-linux.server-image` outputs both build the Radxa SD card image;
the architecture identifies the build host. `packages.x86_64-linux.iso` builds
the PC installer ISO. These package outputs are build artifacts, not additional
machines.

`~/nix/build-iso.sh` builds the PC ISO from `~/dotfiles/nixos` by default, so
changes do not need to be copied into `/etc/nixos` first. Optional arguments
still select another flake and output directory. Bootvine starts in the ISO's
initrd and also displays shutdown progress.

## Docker credentials

Laptop and desktop use GNOME Keyring, unlocked by the password entered at Ly
login. Seahorse manages the saved credentials. The server uses `pass` with
terminal GPG unlock prompts. Docker automatically detects the selected helper.

Before applying this change, remove the old file-based IVCR login on each machine:

```sh
docker logout ivcr.server.ivsop.dev
```

After rebuilding, start a new login session. On the laptop/desktop, run
`ivcr_login`. On the server, initialize `pass` once before logging in:

```sh
gpg --full-generate-key
# Use the fingerprint of the encryption-capable key you created:
pass init YOUR_GPG_KEY_FINGERPRINT
ivcr_login
```

Keep a passphrase on the GPG key. Subsequent credential reads prompt in the
terminal when the GPG agent needs unlocking. Existing explicit Docker
`credsStore` or `credHelpers` settings take precedence over auto-detection.
