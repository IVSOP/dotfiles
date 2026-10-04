# ROCK 4C+ server

`server.nix` contains the server policy; `rock-4c-plus.nix` contains board support;
`rock-server.nix` combines them. No workstation configuration, desktop, or development
packages are imported. The username is `radxa`, hostname is `rock-server`, and the
six public keys in `../trusted-ssh-keys.nix` are shared with both existing computers.
`radxa-defaults.nix` ports Radxa's applicable system and hardware configuration;
`rock-wireless-firmware.nix` packages the ROCK's Broadcom Wi-Fi and Bluetooth firmware.
Add any further trusted public keys there before building. Passwords and Tailscale
credentials are set on the machine and survive rebuilds.

## Build on the fast computer

On your build machine with Nix, run:

```sh
~/nix/radxa/build-img.sh -L
```

The script forwards `"$@"` to `nix build`. Override locations with `SERVER_FLAKE`
and `SERVER_OUT_DIR`. It uses `path:` so new configuration files are included
before `git add`.

The output is `~/nix/radxa/rock-server.img.zst`: the **directly bootable server**,
not an installer or PC ISO. It includes the partition layout, U-Boot for ROCK 4C+,
its device tree, kernel, server closure, and a writable copy of this configuration
at `/etc/nixos`. The ROCK does not evaluate or compile anything during setup.

An x86 Linux build host needs ARM64 binfmt/QEMU or a remote ARM64 builder for ARM
build steps. On NixOS, use `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];`.
On other Linux hosts, register an AArch64 QEMU binfmt interpreter and allow
`aarch64-linux` in Nix's `extra-platforms`. An ARM64 Linux host can build natively.
Installing Nix alone does not enable ARM execution. The x86 image target builds
the GPIO compatibility kernel with a native x86-to-ARM64 compiler. The ARM64
image target builds its kernel natively. Later builds reuse the kernel.
The separate `~/nix/build-iso.sh` builds your PC installer ISO.

## SSH keys

For SSH **into the ROCK**, the connecting laptop or desktop needs a private key
whose public key is listed in `../trusted-ssh-keys.nix`. Reuse an existing matching
keypair; the image already authorizes the six listed public keys.

If the connecting computer has no suitable keypair, run these commands **on that
computer**, choosing an unused filename:

```sh
install -d -m 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/rock4_ed25519 -C "radxa-to-rock4"
cat ~/.ssh/rock4_ed25519.pub
```

Add the public key line to `../trusted-ssh-keys.nix`, then build the image or
build and deploy an updated configuration for an already installed ROCK (see the
later update instructions). Keep the private key on the connecting computer.
Connect over Tailscale with:

```sh
ssh -i ~/.ssh/rock4_ed25519 radxa@TAILSCALE_IP
```

The ROCK stores authorized keys in `/etc/ssh/authorized_keys.d/radxa`.
`/home/radxa/.ssh` does not need to exist for incoming SSH, and this configuration
does not read `~/.ssh/authorized_keys`. SSH host keys identifying the ROCK are
created automatically under `/etc/ssh`.

If the ROCK itself needs to initiate SSH connections, such as accessing a private
Git repository, log in on the ROCK as `radxa` and run:

```sh
ssh-keygen -t ed25519 -C "radxa@rock4"
```

Accept the default filename to create `~/.ssh/id_ed25519` and its `.pub` file.
Authorize that public key on the destination service or computer. This outgoing
keypair is optional and is separate from the keys used to log into the ROCK.

## Your manual steps

1. **Flash the final SD card.** Check the device name with `lsblk`. For example:

   ```sh
   zstd -dc ~/nix/radxa/rock-server.img.zst | sudo dd of=/dev/SD_CARD bs=4M status=progress conv=fsync
   ```

   Replace `/dev/SD_CARD` with the whole card device. This erases it. The image
   already contains partitions and the system: no second installer card, manual
   partitioning, or installation command is needed. Use at least 16 GB for Docker
   space. Root expands to use the card on first boot.

2. **Set passwords manually.** Insert the card into the ROCK, connect Ethernet,
   a keyboard, and the ordinary HDMI output. At the local login prompt, enter
   `root`; it initially has no password. Then run:

   ```sh
   passwd root
   passwd radxa
   exit
   ```

   The first password protects local root recovery; the second is your console
   and sudo password. `radxa` starts password-locked until you set it. There
   is no guided password service or autologin. Password changes survive reboots
   and rebuilds because `users.mutableUsers` is enabled. Root/password SSH is
   disabled, so the initial passwordless root access is local-console-only.

3. **Tailscale login.** Log in as `radxa`, run `sudo tailscale up`, and follow
   the login URL. Then run `tailscale ip -4` and SSH to `radxa@TAILSCALE_IP` using
   a trusted key. Tailscale reconnects after reboot; tailnet access policy and
   credential expiry are managed separately in your Tailscale account.

4. **Your application.** Transfer it separately and run `docker compose up -d`.
   Use `restart: unless-stopped` (or `always`) for containers that should restart
   after power loss. Docker and Tailscale already start on boot.

NetworkManager handles Ethernet DHCP. Optional Wi-Fi setup is
`sudo nmcli --ask device wifi connect 'YOUR_SSID'`; the saved connection survives
reboots without putting its password in the Nix store. Bluetooth starts too.
SSH is blocked on the LAN; root SSH and password SSH are disabled. After password
setup and Tailscale login, remove the display and keyboard if desired.

## Wi-Fi detection

Before connecting, check `nmcli device status`. A Wi-Fi interface should appear;
`nmcli radio wifi on` enables the radio but cannot fix a failed driver probe.
For a missing interface, inspect:

```sh
sudo journalctl -k -b --no-pager | grep -Ei 'brcm|firmware|mmc|sdio|rfkill'
ls -l /sys/bus/sdio/devices/
```

The tested board identifies its Wi-Fi chip as BCM4345/6. Mainline Linux requests
`brcm/brcmfmac43455-sdio.bin`, its NVRAM `.txt`, and its `.clm_blob`; Bluetooth
requests `brcm/BCM4345C0.hcd`. The small firmware package includes these alongside
the existing 43456/C5 files. A failed generic firmware request with error `-2`
means a file is missing. A failed board-specific request alone can be harmless
when the driver successfully falls back to the generic filename.

## Network and GPIO behavior

Host service connections are accepted only on `tailscale0`; LAN/WAN SSH and
application connections are blocked. Outbound traffic, connection replies, DHCP,
and essential IPv6 control traffic work. Tailscale's public UDP port stays closed;
it can use outbound traversal or relays.

Docker's published ports bypass the normal INPUT firewall. The separate IPv4/IPv6
`docker-ingress` nftables forwarding chain blocks incoming DNAT/published ports
and direct routing into Docker's usual `docker0`/`br-*` bridges from other interfaces.
It preserves outgoing container traffic, replies, and inter-container traffic.
Firewall reloads do not flush Docker's or Tailscale's tables. Docker starts only
after the guard firewall has loaded. Use standard Docker/Compose bridge networks;
custom bridge names need corresponding changes to the forwarding rules. Avoid
macvlan/ipvlan networks if you expect this host firewall to protect the containers,
because those network types can bypass the host's network stack.

`gpio` group membership gives `radxa` access to `/dev/gpiochip*`; no sudo is needed
for the Rust counter after login. The board kernel explicitly enables
`CONFIG_GPIO_CDEV` and `CONFIG_GPIO_CDEV_V1`, which `gpio-cdev` 0.6 needs. The existing
physical pins and bank-local offsets stay the same; chip device numbering may
change, which is why the counter discovers bank labels. No UART/SPI overlays are
enabled on the counter's pins. Validate wiring and run `--list-gpio` before use.

The user also gets Radxa's audio/video/render/plugdev and I²C/SPI/PWM groups.
I²C character devices, SPI character devices, and exported PWM channels receive
group permissions. This grants access to interfaces the kernel already exposes;
it does not enable UART/SPI/I²C overlays or remap pins used by the counter.

Radxa's memory defaults are ported directly: zstd zram with logical capacity 50%
of RAM; swappiness 100; vfs_cache_pressure 500; dirty_background_ratio 1;
dirty_ratio 50; min_free_kbytes 16384; max_map_count 1048576. Zram uses RAM as
needed, not a preallocated reservation of half your RAM, and has no disk writeback.
The larger dirty-page limit also means more writes can remain buffered in RAM.
Suspend and hibernation targets are disabled. Standard LED-trigger modules load
at boot, and irqbalance uses Radxa's `IRQBALANCE_BANNED_CPULIST=0-3` RK3399 policy.

The CPU governor stays `schedutil`, the modern scheduler-integrated default.
Radxa's `ondemand` settings are present but inactive. Setting
`powerManagement.cpuFreqGovernor = "ondemand";` explicitly enables its tuning
service (io_is_busy=1, sampling_down_factor=10, sampling_rate=200000,
up_threshold=25), for global or per-policy governor attributes. There is no
board-specific benchmark here showing that changing governors helps.

For later updates, build `nixosConfigurations.rock-server.config.system.build.toplevel`
on the fast computer and deploy it over Tailscale with `nixos-rebuild --target-host`
and remote sudo. Do not reinstall/reformat for routine updates: `/var/lib/docker`,
`/var/lib/tailscale`, passwords, and SSH host keys are persistent local state.

## Printer and QR reader

`radxa` is also in `lp` and `dialout` for printer/serial device access. No printing
daemon or printer suite is installed. Once the models are known, choose direct
ESC/POS, CUPS, serial, or libusb access and add any device-specific udev rule.
The app's Compose file will need the relevant device paths/groups passed through.
For still images containing text, QR codes, and overlays, start with CPU rendering;
hardware acceleration needs a separate measured benefit and matching drivers.

## Kernel audit

See [SERVER-KERNEL-AUDIT.md](SERVER-KERNEL-AUDIT.md) for the official kernel
selection, its patch/configuration layers, why the vendor fork exists, and the
board support comparison. The current lock selects mainline Linux 6.18.54.
It describes the standard HDMI path; the vendor second-display path is absent.
Use the ordinary HDMI output or UART2 serial console for manual initial setup. The initrd
explicitly includes the storage controllers, USB PHYs, and USB storage drivers.

## Validation

The server and image derivations can be evaluated without building the image:

```sh
nix eval --raw 'path:./#nixosConfigurations.rock-server.config.system.build.toplevel.drvPath'
nix eval --raw 'path:./#packages.x86_64-linux.server-image.drvPath'
```

Evaluation does not prove a successful kernel/image build or a physical boot.
The actual ROCK boot and GPIO signals must be checked on the board.
