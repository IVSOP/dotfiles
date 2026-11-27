# Install NixOS

Boot the installer USB in UEFI mode with internet access and Secure Boot disabled.
Run installer commands as root. For Radxa, use [its guide](radxa/SERVER.md).

## 0. Prepare disks

Skip to step 1 if already prepared. **Formatting erases data.** Replace device
placeholders with your partitions.

```sh
sudo -i
lsblk -f
test -d /sys/firmware/efi
```

Example GPT layout:

| Disk | Partition | Size | Use |
| --- | --- | --- | --- |
| First | EFI System | 1 GiB | FAT32, `/boot/efi` |
| First | Linux filesystem | 2 GiB | ext4, `/boot` |
| First | LVM or LUKS | Remaining | First physical volume |
| Second | LVM or LUKS | Available | Second physical volume |

```sh
efi_part=/dev/disk/by-id/REPLACE_EFI_PARTITION
boot_part=/dev/disk/by-id/REPLACE_BOOT_PARTITION
pv1_part=/dev/disk/by-id/REPLACE_FIRST_LVM_PARTITION
pv2_part=/dev/disk/by-id/REPLACE_SECOND_LVM_PARTITION

mkfs.fat -F 32 -n EFI "$efi_part"
mkfs.ext4 -L boot "$boot_part"
```

Choose **unencrypted LVM**:

```sh
pv1="$pv1_part"
pv2="$pv2_part"
```

Or **LVM over LUKS**:

```sh
cryptsetup luksFormat --type luks2 "$pv1_part"
cryptsetup open "$pv1_part" crypt_pv1
cryptsetup luksFormat --type luks2 "$pv2_part"
cryptsetup open "$pv2_part" crypt_pv2
pv1=/dev/mapper/crypt_pv1
pv2=/dev/mapper/crypt_pv2
```

Then create root and 8 GiB swap:

```sh
pvcreate "$pv1" "$pv2"
vgcreate lvm_group "$pv1" "$pv2"
lvcreate -L 8G -n swap lvm_group
lvcreate -l 100%FREE -n root lvm_group
mkfs.ext4 -L nixos /dev/lvm_group/root
mkswap -L swap /dev/lvm_group/swap
```

This layout has no disk redundancy. LUKS encrypts root and swap, leaving boot
and EFI unencrypted.

## 1. Mount filesystems

For LUKS, open containers that are not already open:

```sh
cryptsetup open /dev/disk/by-id/REPLACE_FIRST_LVM_PARTITION crypt_pv1
cryptsetup open /dev/disk/by-id/REPLACE_SECOND_LVM_PARTITION crypt_pv2
```

Use your volume group name and labels. Skip mounts and swap already active.

```sh
vgchange -ay lvm_group
mount /dev/lvm_group/root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
mkdir -p /mnt/boot/efi
mount /dev/disk/by-label/EFI /mnt/boot/efi
swapon /dev/lvm_group/swap

findmnt -R /mnt
swapon --show
```

Mount any separate `/home` filesystem now.

## 2. Prepare the NixOS configuration

### Clone the dotfiles repository

Clone the full repository into `/tmp` on the live installer. If restoring a
backup with local changes, put the checkout at `/tmp/dotfiles` and skip the
clone.

```sh
cd /tmp
git clone https://github.com/IVSOP/dotfiles.git ./dotfiles
```

### Copy the flake to `/mnt/etc/nixos`

```sh
cd /tmp/dotfiles/nixos
mkdir -p /mnt/etc/nixos
cp -r flake.nix flake.lock pins.nix sources.json trusted-ssh-keys.nix \
  hosts profiles modules images /mnt/etc/nixos/
```

### Generate the hardware configuration

| Machine | `target` | Settings file |
| --- | --- | --- |
| Server | `server` | `hosts/server/default.nix` |
| Laptop | `ivX13` | `hosts/ivX13/default.nix` |
| Desktop | `IVPC` | `hosts/IVPC/default.nix` |

Set `target` for this machine. Generate its hardware configuration in
`/mnt/etc/nixos` using the mounted filesystems and active swap.

```sh
cd /mnt/etc/nixos
target=server  # Use ivX13 for the laptop or IVPC for the desktop.
nixos-generate-config --root /mnt --show-hardware-config \
  > "hosts/$target/hardware-configuration.nix"
```

### Adapt the host's `default.nix`

Edit `hosts/$target/default.nix` in `/mnt/etc/nixos`. Review these settings
for the new machine.

- **EFI mount.** Match `boot.loader.efi.efiSysMountPoint` to where you mounted
  the EFI partition on the installed system. If it is at `/mnt/boot/efi` in the
  installer, use `/boot/efi`. The server and laptop already use that value.
  On `IVPC`, uncomment the setting when following this layout.
- **Hostname.** Set `networking.hostName` if this machine needs a different
  hostname. Keep using the selected flake target for installation and pass it
  explicitly to the maintenance scripts when the hostname differs.
- **Server.** Use `ip -br link` and `ip -4 route` to check the interface and
  network. Update `lanInterface` and `lanSubnet` for the LAN and Docker ingress
  rules. In the `server-lan` NetworkManager profile, set `ipv4.address1` to an
  unused static address with its prefix and `ipv4.gateway` to your router.
  Update the fallback in `ipv4.dns` for when `useAdguardDNS` is `false`. Review
  the Intel microcode setting and Intel graphics packages if the CPU or GPU differs.
  [SERVER.md](SERVER.md)
- **Laptop.** On a different laptop, review the `services.logind.settings.Login`
  lid and suspend-key behavior and the TLP power profiles and battery charge
  thresholds.

#### LUKS mappings

Review `boot.initrd.luks.devices` in both the generated file and the host's
`default.nix`. The existing `ivX13` mapping points to the original laptop's
disk. Remove it for an unencrypted install.

For LVM over LUKS, check that every encrypted physical volume has an unlock
mapping. The generator may see the mounted logical volumes without detecting
their underlying LUKS containers. In the host's `default.nix`, add any missing
mappings and update stale ones. Use the names you passed to `cryptsetup open`
and get each container's UUID with `cryptsetup luksUUID /dev/your-partition`.

```nix
boot.initrd.luks.devices = {
  crypt_pv1.device = "/dev/disk/by-uuid/REPLACE_FIRST_LUKS_UUID";
  crypt_pv2.device = "/dev/disk/by-uuid/REPLACE_SECOND_LUKS_UUID";
};
```

Keep one mapping per actual container across the two files.

### Temporary installation edits

For the server, change the existing bindings in `hosts/server/default.nix`:

```nix
# Use router DNS until AdGuard is running; restore true afterward.
useAdguardDNS = false;
# Keep Tailscale off until ready to log in; restore true and rebuild afterward.
enableTailscale = false;
```

For the initial x86 install, keep Secure Boot off in the firmware and change
the existing `boot.lanzaboote.enable` line in
`/mnt/etc/nixos/hosts/$target/default.nix` from `true` to `false`. The target
uses stock systemd-boot for installation and first boot.

```nix
boot.lanzaboote.enable = false;
```

Set it back to `true` during [post-install Secure Boot setup](#secure-boot-all-x86-machines)
after creating the signing keys.

### Copy the changes back to the temporary checkout

After generation succeeds and you finish editing, copy the updated flake back
to `/tmp/dotfiles` so it includes this machine's hardware and host settings.

```sh
cp -r /mnt/etc/nixos/. /tmp/dotfiles/nixos/
```

## 3. Install

```sh
nixos-install --root /mnt --flake "path:/mnt/etc/nixos#$target"
```

Set the root password when prompted. If Nix reports disabled flake features,
retry with `--option extra-experimental-features 'nix-command flakes'`.
Continue only after installation succeeds.

## 4. Set the password, copy the dotfiles, and reboot

`nixos-enter` runs the installed system's activation, which creates the
`ivsopi3` account and its home directory with the configured permissions.

```sh
nixos-enter --root /mnt -c 'passwd ivsopi3'
```

Once the home exists, copy the updated checkout into it. Since the installer
runs as root, set ownership on the copied checkout. If the home already has a
`dotfiles` checkout, move it aside first.

```sh
cp -aT /tmp/dotfiles /mnt/home/ivsopi3/dotfiles &&
  nixos-enter --root /mnt -c 'chown -hR ivsopi3:users /home/ivsopi3/dotfiles' &&
  reboot
```

Remove the USB and log in locally as `ivsopi3` with the password just set.

## 5. Post-install setup

Run as `ivsopi3`. Set your machine's target again after reboot:

```sh
target=server # ivX13 for laptop; IVPC for desktop
```

### SSH keys (all machines)

Restore your private keys into `~/.ssh`, or create a key if none exists:

```sh
install -d -m 700 ~/.ssh
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-add ~/.ssh/id_ed25519
```

Register `~/.ssh/id_ed25519.pub` with the Git hosts or machines you access.
For incoming SSH, add the connecting client's public key to
`~/dotfiles/nixos/trusted-ssh-keys.nix` and run
`~/dotfiles/nixos/rebuild.sh "$target"`. Its private key stays on the client.

### Tailscale and remote login (all machines)

On the server, restore `enableTailscale = true` in
`~/dotfiles/nixos/hosts/server/default.nix`, keep `useAdguardDNS = false`, and
rebuild.

```sh
~/dotfiles/nixos/rebuild.sh "$target"
```

This starts Tailscale immediately and enables it for future boots on the server.

Laptop/desktop only: start the manually configured daemon:

```sh
sudo systemctl start tailscaled
```

Then, on all machines:

```sh
sudo tailscale up
tailscale status
tailscale ip -4
```

Open the login URL printed by `tailscale up`.
On laptop/desktop, also start SSH when you want incoming connections:

```sh
sudo systemctl start sshd
```

From another device on Tailscale, replace `HOST` with the machine's hostname
or printed Tailscale IP:

```sh
ssh -i ~/.ssh/id_ed25519 ivsopi3@HOST
```

SSH uses the client key; `sudo` uses your local password. On laptop/desktop,
start `tailscaled` and `sshd` again after reboot when needed.

### AdGuard and DNS (server only)

Restore the AdGuard Compose stack and data. From its directory:

```sh
sudo docker compose up -d
dig @127.0.0.1 example.org
dig +tcp @127.0.0.1 example.org
```

Once both checks pass, restore `useAdguardDNS = true` in
`~/dotfiles/nixos/hosts/server/default.nix` and rebuild.

```sh
~/dotfiles/nixos/rebuild.sh "$target"
cat /etc/resolv.conf
getent hosts example.org
```

The resolver should be `127.0.0.1`. Keep AdGuard's upstream and bootstrap
resolvers independent of the host's loopback resolver.

### Secure Boot (all x86 machines)

```sh
sudo sbctl create-keys
```

Set `boot.lanzaboote.enable` back to `true` in
`~/dotfiles/nixos/hosts/$target/default.nix` to restore signing.

Rebuild and verify the signed boot files.

```sh
~/dotfiles/nixos/rebuild.sh "$target"
sudo sbctl verify
```

Follow the [Lanzaboote guide](https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html)
to enter firmware Setup Mode and enroll the keys with
`sudo sbctl enroll-keys --microsoft`. Enable Secure Boot in firmware if needed,
then reboot and check `bootctl status` and `sudo sbctl status`: Secure Boot
must be enabled and Setup Mode disabled.

## 6. Later changes

For routine changes, edit `~/dotfiles/nixos` and use the maintenance scripts.
They copy the configuration and lock file to `/etc/nixos` before rebuilding:

```sh
cd ~/dotfiles/nixos
./rebuild.sh
./update.sh  # Show manual pins, update other inputs/sources, copy and rebuild
./gc.sh      # Copy, remove old generations, and rebuild the boot configuration
```

The scripts default to your hostname; pass `ivX13`, `IVPC`, or `server` to
select a target explicitly. See [README.md](README.md) for details.

See [SERVER.md](SERVER.md) for server services.
