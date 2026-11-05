# NixOS machines

This configuration manages four separate machines:

| Machine | Hostname / flake target | Architecture | User | Machine configuration |
| --- | --- | --- | --- | --- |
| Laptop | `ivX13` | `x86_64-linux` | `ivsopi3` | [laptop.nix](laptop.nix) |
| Desktop | `IVPC` | `x86_64-linux` | `ivsopi3` | [desktop.nix](desktop.nix) |
| Server | `server` | `x86_64-linux` | `ivsopi3` | [server.nix](server.nix) |
| Radxa server (ROCK 4C+) | `rock-server` | `aarch64-linux` | `radxa` | [radxa/rock-server.nix](radxa/rock-server.nix) |

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
- The Radxa server combines [radxa/server.nix](radxa/server.nix) with
  [radxa/rock-4c-plus.nix](radxa/rock-4c-plus.nix). Its flake target uses
  [radxa/server-image.nix](radxa/server-image.nix) to add image provisioning.
  It does not import the shared workstation or development configuration.
- [trusted-ssh-keys.nix](trusted-ssh-keys.nix) supplies authorized SSH public
  keys for all four machines. The laptop, desktop, and x86 server also use
  `dotfiles.nix` for their dotfile links.

## Rebuild an installed x86 machine

Run the matching command from this directory on the machine being updated.
Target names are case-sensitive:

```sh
# Laptop
sudo nixos-rebuild switch --flake 'path:./#ivX13'

# Desktop
sudo nixos-rebuild switch --flake 'path:./#IVPC'

# Server
sudo nixos-rebuild switch --flake 'path:./#server'
```

The `path:./` form includes new files before they are tracked in Git. Once all
configuration files are tracked, `.#TARGET` also works.

For the Radxa server, follow the [image build and deployment guide](radxa/SERVER.md).
The `packages.x86_64-linux.server-image` and
`packages.aarch64-linux.server-image` outputs both build the Radxa SD card image;
the architecture identifies the build host. `packages.x86_64-linux.iso` builds
the PC installer ISO. These package outputs are build artifacts, not additional
machines.
