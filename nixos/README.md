# NixOS machines

This configuration manages four separate machines:

| Machine | Hostname / flake target | Architecture | User | Machine configuration |
| --- | --- | --- | --- | --- |
| Laptop | `ivX13` | `x86_64-linux` | `ivsopi3` | [laptop.nix](laptop.nix) |
| Desktop | `IVPC` | `x86_64-linux` | `ivsopi3` | [desktop.nix](desktop.nix) |
| Server | `server` | `x86_64-linux` | `ivsopi3` | [server.nix](server.nix) |
| Radxa server (ROCK 4C+) | `rock-server` | `aarch64-linux` | `radxa` | [radxa/rock-server.nix](radxa/rock-server.nix) |

For a fresh laptop, desktop, or x86 server install, start with the
[simple installation guide](INSTALL.md). It covers disk preparation with optional
LUKS encryption and installation from files copied into `/mnt/etc/nixos`.

The server and Radxa server have separate configurations and setup procedures:

- [Server setup](SERVER.md): the x86 server, installed with `nixos-install`.
- [Radxa server setup](radxa/SERVER.md): the ARM board, flashed with a bootable SD card image.
- [Radxa kernel audit](radxa/SERVER-KERNEL-AUDIT.md): board and kernel support details.

## Configuration layout

[flake.nix](flake.nix) defines the four `nixosConfigurations` targets above.

- The laptop and desktop share [configuration.nix](configuration.nix), which
  provides the Hyprland desktop and imports [common.nix](common.nix) and
  [development.nix](development.nix). Each machine imports its own hardware
  configuration through `laptop.nix` or `desktop.nix`.
- The x86 server imports `common.nix`, `development.nix`, and
  [dotfiles.nix](dotfiles.nix), without enabling a desktop session. Its hardware
  configuration is [server-hardware-configuration.nix](server-hardware-configuration.nix).
- The three x86 hosts and PC installer ISO share [bootvine.nix](bootvine.nix)
  for the boot, LUKS prompt, and shutdown display. The Radxa does not use Bootvine.
- The Radxa server combines [radxa/server.nix](radxa/server.nix) with
  [radxa/rock-4c-plus.nix](radxa/rock-4c-plus.nix). Its flake target uses
  [radxa/server-image.nix](radxa/server-image.nix) to add image provisioning.
  It does not import the shared workstation or development configuration.
- [trusted-ssh-keys.nix](trusted-ssh-keys.nix) supplies authorized SSH public
  keys for all four machines. The laptop, desktop, and x86 server also use
  `dotfiles.nix` for their dotfile links.

## Rebuild an installed x86 machine

Edit the files in this repository, then run these scripts as your normal user
(they call `sudo` where needed):

```sh
# Copy the configuration to /etc/nixos and switch to it
./rebuild.sh

# Show manual pins, update other inputs and source versions, then copy and rebuild
./update.sh

# Copy the configuration, collect garbage, delete old generations,
# and rebuild the boot configuration
./gc.sh
```

Each script works from any directory and defaults to the current hostname.
You can pass a case-sensitive target explicitly, for example
`./rebuild.sh IVPC`; supported targets are `ivX13`, `IVPC`, and `server`.
The target selects the configuration on the local machine, not a remote host.

All three copy the top-level `.nix` files, `sources.json`, and `flake.lock` to `/etc/nixos`
before rebuilding with `--flake path:/etc/nixos#TARGET`. This includes new
files before they are tracked in Git. Existing unrelated files in `/etc/nixos`
are preserved; the `radxa/` directory is not copied.

`gc.sh` runs `sudo nix-store --gc`, `sudo nix-collect-garbage -d`, and then
`sudo nixos-rebuild boot`. It deletes old generations and updates the boot
configuration without switching the running system. Scripts stop if a command
fails.

`update.sh` updates all inputs except those fixed to commits in `flake.nix`.
The manual pins are Hyprland and its portal, hy3, Solana CLI, Anchor, the SBF
builder and platform tools, Tracy, and Bootvine. General stable/nightly Rust,
Lanzaboote, VS Code extensions, and Waybar update normally.

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
