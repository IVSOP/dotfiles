# Regular x86 server

The flake target is `server`, with hostname `server` and user `ivsopi3`.
`server.nix` imports the same `common.nix`, `development.nix`, and `dotfiles.nix`
used by the desktop and laptop. These share the CLI packages, Git configuration,
Zsh/SSH agent, development packages (including stable/nightly Rust, cross targets,
Solana/Anchor, VS Code extensions, Android/Unity tools, and database tools),
tmpfs `/tmp`, swappiness `1`, and a `100M` journal limit. Graphical development
applications are installed to keep the toolsets identical; no desktop session is
enabled on the server.

Docker, SSH, Tailscale, NetworkManager, and Bluetooth start at boot. NetworkManager
provides `nmcli`/`nmtui`; BlueZ provides `bluetoothctl`. Sleep targets are disabled.
The requested DNS, transfer, compression, media, backup, and monitoring tools are
installed; restic repositories and backup schedules are configured separately.

## Installation

1. Replace `server-hardware-configuration.nix` with the target machine's hardware
   configuration from `nixos-generate-config`. The checked-in file is a template
   using `NIXOS_SERVER` and `NIXOS_SERVER_BOOT` filesystem labels, with no swap;
   it does not describe the laptop's or desktop's disks. The default bootloader
   is systemd-boot for UEFI, without the workstations' Secure Boot key requirement.
   Adjust `server.nix` if the server uses legacy BIOS.
2. Keep a checkout of the full dotfiles repository at `/home/ivsopi3/dotfiles`
   on the installed server. The symlinks point into that checkout and do not copy
   its contents into the Nix store. Fresh installs also get packaged Oh My Zsh
   with `fzf-tab`; an existing `~/.oh-my-zsh` directory is preserved.
3. From the checkout's `nixos` directory, evaluate/build before installing:

   ```sh
   nix build 'path:./#nixosConfigurations.server.config.system.build.toplevel'
   ```

   For a new installation with its filesystems mounted at `/mnt`, use
   `sudo nixos-install --flake 'path:./#server'`. For an existing server, use
   `sudo nixos-rebuild switch --flake 'path:./#server'`.
4. Set a local password for `ivsopi3` using `passwd ivsopi3` on the server console
   (or through `nixos-enter --root /mnt` before reboot) so sudo works. SSH accepts
   only the keys in `trusted-ssh-keys.nix`; root SSH and password SSH are disabled.
5. From the console, run `sudo tailscale up` once. Subsequent boots reconnect
   using the saved state. Connect with `ssh ivsopi3@server` over the tailnet.

The `path:./` form includes new, untracked Nix files while preparing the config.
After tracking those files in Git, `.#server` also works.

## Firewall and containers

The NixOS firewall uses nftables and trusts `tailscale0`, so host services are
reachable from the tailnet, subject to its access rules. No TCP ports are opened
on physical interfaces. UDP 41641 is opened for Tailscale's encrypted transport;
normal firewall allowances for DHCP and ICMP remain enabled.

Docker's published ports traverse forwarding rules after DNAT, so the server
also filters container ingress in a separate nftables table. Physical-interface
traffic to published ports or standard Docker bridges is dropped; Tailscale,
container egress, inter-container traffic, and established replies are allowed.
Reloading nftables preserves Docker's and Tailscale's own tables. This follows
Docker's documented [packet filtering behavior](https://docs.docker.com/engine/network/packet-filtering-firewalls/).
Containers using host networking follow the host firewall; macvlan/ipvlan networks
and custom bridge interface names need their own policy.

The uncommitted Radxa additions now live here:

- `docker-proxy-network.service` ensures the external `proxy` bridge exists at
  `172.18.0.0/16`, gateway `172.18.0.1`, whenever Docker starts. Existing networks
  are preserved. Check that this subnet does not overlap the server's LAN/VPN.
- `/services/traefik/certs` is created with mode `0700`, owned by root.

Compose still manages the stacks and their private networks. Reference the
shared network as external:

```yaml
networks:
  proxy:
    external: true
```

For systemd-managed Compose stacks, add `requires` and `after` dependencies on
`docker-proxy-network.service` so their initial startup waits for the network.
Traefik and its application/domain/certificate configuration remain in Compose.
