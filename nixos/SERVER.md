# Server (x86)

This guide covers the x86 `server`, one of the [four machines](README.md).
For the separate Radxa server (`rock-server`), see [its setup guide](radxa/SERVER.md).

The flake target is `server`, with hostname `server` and user `ivsopi3`.
Lanzaboote signs the boot files using keys in `/var/lib/sbctl`, and `sbctl` is
installed for key management and verification. Follow the Secure Boot steps in
[INSTALL.md](INSTALL.md#secure-boot-all-x86-machines) to create and enroll keys;
enabling Lanzaboote in Nix does not itself enable firmware enforcement.

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

The LAN connection uses a declarative NetworkManager profile, `server-lan`, with
static IPv4 address `192.168.1.228/24` on `enp2s0` and gateway `192.168.1.1`,
matching the live Arch server. IPv4 DHCP is disabled for this profile, and
NetworkManager does not create automatic DHCP profiles for unused Ethernet ports.
IPv6 remains automatic. Exclude or reserve `192.168.1.228` in the router's DHCP
pool to prevent address conflicts. By default, the server uses local AdGuard DNS
at `127.0.0.1`. Temporarily set `useAdguardDNS = false` during installation to use
router DNS until AdGuard is running. Set `enableTailscale = false` to keep
Tailscale off until post-install setup.

Intel CPU microcode updates are enabled explicitly. On Intel machines,
`nixos-generate-config` normally enables them through a default in the generated
hardware configuration too. Native host applications have hardware graphics
enabled with `intel-media-driver` for VA-API and `intel-compute-runtime` for
OpenCL. Docker images provide their own user-space acceleration libraries and
access the GPU through their Compose device mappings.

## Installation

Follow [INSTALL.md](INSTALL.md): copy the configuration into `/mnt/etc/nixos`,
generate this server's hardware file, and install with the `server` target.

- Copy the generated `hardware-configuration.nix` to `server-hardware-configuration.nix`.
- Check network settings in `server.nix`.
- Keep the full dotfiles checkout at `/home/ivsopi3/dotfiles`.

SSH accepts configured keys only; root SSH and password SSH are disabled.

For console login, SSH keys, Tailscale, and AdGuard DNS, follow
[post-install setup in INSTALL.md](INSTALL.md#5-post-install-setup).

## Firewall and containers

The NixOS firewall uses nftables and trusts `tailscale0`, so host services are
reachable from the tailnet, subject to its access rules. No host-service TCP
ports are opened on physical interfaces; published container exceptions are
described below. UDP 41641 is opened for Tailscale's encrypted transport; normal
firewall allowances for DHCP and ICMP remain enabled.

Docker's published ports traverse forwarding rules after DNAT, so the server
also filters container ingress in a separate nftables table. On `enp2s0`, this
allows published AdGuard DNS on TCP/UDP 53 from the LAN (`192.168.1.0/24`) and
published qBittorrent peer traffic on TCP/UDP 6881 from any source. The checks
match both the original published port and the container's destination port.
Other physical-interface traffic to published ports or standard Docker bridges
is dropped; Tailscale, container egress, inter-container traffic, and established
replies are allowed. Check the interface and LAN subnet when installing.
Reloading nftables preserves Docker's and Tailscale's own tables. This follows
Docker's documented [packet filtering behavior](https://docs.docker.com/engine/network/packet-filtering-firewalls/).
Containers using host networking follow the host firewall; macvlan/ipvlan networks
and custom bridge interface names need their own policy.

Published Docker ports can bypass the normal host firewall on both Arch/UFW and
NixOS. The separate forwarding filter above enforces these restrictions; opening
only `networking.firewall.allowedTCPPorts` or `allowedUDPPorts` does not create
exceptions to it. For incoming internet torrent peers, forward TCP/UDP 6881 on
the router to the server's fixed LAN address (currently `192.168.1.228`).
qBittorrent's web UI remains behind Traefik over Tailscale. Jellyfin uses its
existing Tailscale HTTPS URL. Palworld also needs no LAN exception when players
use Tailscale: connect directly to `server:8211` in the game, rather than through
the HTTPS proxy. Game port 8211, query port 27015, and the admin API remain
restricted to Tailscale and local/container traffic.

The x86 server also configures the following Docker infrastructure:

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
