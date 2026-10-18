{ config, lib, pkgs, ... }:

{
  imports = [ ./desktop-hardware-configuration.nix ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "IVPC";

  # ── SSH keys ────────────────────────────────────────────────────────
  # Shared with the laptop and server.
  users.users.ivsopi3.openssh.authorizedKeys.keys = import ./trusted-ssh-keys.nix;

  # ── Disk ─────────────────────────────────────────────────────────────
  # Replace desktop-hardware-configuration.nix with this machine's generated
  # hardware configuration when installing. Set any LUKS devices here.
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.initrd.luks.devices."crypt_0" = {
  #   device = "/dev/disk/by-uuid/REPLACE-ME";
  #   preLVM = true;
  # };
}
