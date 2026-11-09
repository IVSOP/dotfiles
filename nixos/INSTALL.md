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

All x86 machines: edit the existing boot settings in `server.nix` for the
server, or `configuration.nix` for the laptop/desktop:

```nix
# Boot without signing until Secure Boot keys are set up.
boot.loader.systemd-boot.enable = lib.mkForce true;
# Restore true after creating the signing keys, before rebuilding and enrolling.
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
`/etc/nixos/trusted-ssh-keys.nix` and rebuild. Its private key stays on the client.

### Tailscale and remote login (all machines)

Server: restore `enableTailscale = true` in `/etc/nixos/server.nix`, keep
`useAdguardDNS = false`, then rebuild:

```sh
sudo nixos-rebuild switch --flake "path:/etc/nixos#$target"
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

Once both checks pass, restore `useAdguardDNS = true` in `/etc/nixos/server.nix`:

```sh
sudo nixos-rebuild switch --flake "path:/etc/nixos#$target"
cat /etc/resolv.conf
getent hosts example.org
```

The resolver should be `127.0.0.1`. Keep AdGuard's upstream and bootstrap
resolvers independent of the host's loopback resolver.

### Secure Boot (all x86 machines)

```sh
sudo sbctl create-keys
```

Restore the existing settings in `/etc/nixos/server.nix` for the server, or
`/etc/nixos/configuration.nix` for the laptop/desktop:

```nix
boot.loader.systemd-boot.enable = lib.mkForce false;
boot.lanzaboote.enable = true;
```

Rebuild and verify the signed boot files:

```sh
sudo nixos-rebuild switch --flake "path:/etc/nixos#$target"
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
./update.sh  # Update nixpkgs, then copy and rebuild
./gc.sh      # Copy, remove old generations, and rebuild the boot configuration
```

The scripts default to your hostname; pass `ivX13`, `IVPC`, or `server` to
select a target explicitly. See [README.md](README.md) for details.

See [SERVER.md](SERVER.md) for server services.
