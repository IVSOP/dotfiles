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

## 2. Copy configuration and generate hardware settings

Copy the existing NixOS files, including `flake.nix`, `flake.lock`, and modules,
to `/mnt/etc/nixos`. Keep the full dotfiles repo at
`/mnt/home/ivsopi3/dotfiles` for the user's dotfile symlinks.

```sh
cd /mnt/etc/nixos
```

| Machine | `target` | `hardware` | Settings file |
| --- | --- | --- | --- |
| Server | `server` | `server-hardware-configuration.nix` | `server.nix` |
| Laptop | `ivX13` | `laptop-hardware-configuration.nix` | `laptop.nix` |
| Desktop | `IVPC` | `desktop-hardware-configuration.nix` | `desktop.nix` |

For the server:

```sh
target=server
hardware=server-hardware-configuration.nix
nixos-generate-config --root /mnt
cp hardware-configuration.nix "$hardware"
```

For another machine, substitute its row's values and settings file.

The server already supplies its boot and network settings. See [SERVER.md](SERVER.md)
to change the configured network address. For the desktop, uncomment its
`boot.loader.efi.efiSysMountPoint = "/boot/efi";` setting.

### Encrypted root only

For LUKS, add any missing mappings to the machine file. Get each UUID with
`cryptsetup luksUUID /dev/your-partition`:

```nix
boot.initrd.luks.devices = {
  crypt_pv1.device = "/dev/disk/by-uuid/REPLACE_FIRST_LUKS_UUID";
  crypt_pv2.device = "/dev/disk/by-uuid/REPLACE_SECOND_LUKS_UUID";
};
```

Declare only your actual encrypted containers, once each across the imported files.

### Temporary installation edits

Server: change the existing bindings in `server.nix`:

```nix
# Use router DNS until AdGuard is running; restore true afterward.
useAdguardDNS = false;
# Keep Tailscale off until ready to log in; restore true and rebuild afterward.
enableTailscale = false;
```

Laptop/desktop: edit the existing settings in `configuration.nix`:

```nix
# Boot without signing until Secure Boot keys are set up.
boot.loader.systemd-boot.enable = lib.mkForce true;
# Restore true after creating and enrolling the signing keys.
boot.lanzaboote.enable = false;
```

## 3. Install

From `/mnt/etc/nixos`:

```sh
nixos-install --root /mnt --flake "path:./#$target"
```

Set the root password when prompted. If Nix reports disabled flake features,
retry with `--option extra-experimental-features 'nix-command flakes'`.
Continue only after installation succeeds.

## 4. Set password and reboot

```sh
nixos-enter --root /mnt -c 'passwd ivsopi3'
nixos-enter --root /mnt -c 'chown -R ivsopi3:users /home/ivsopi3/dotfiles'
reboot
```

Remove the USB and log in at the server's console as `ivsopi3`, using the
password just set. Follow [post-install setup](SERVER.md#post-install-setup)
for SSH keys, Tailscale login, AdGuard, and switching DNS.

## 5. Later changes

Edit `/etc/nixos`, then rebuild. For the server:

```sh
sudo nixos-rebuild switch --flake 'path:/etc/nixos#server'
```

See [SERVER.md](SERVER.md) for server services, or the
[Lanzaboote guide](https://nix-community.github.io/lanzaboote/) to enable Secure Boot later.
Restore the temporary Tailscale, DNS, or boot settings after their setup.
