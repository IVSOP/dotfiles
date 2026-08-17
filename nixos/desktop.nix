{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "IVPC";

  # ── SSH keys ────────────────────────────────────────────────────────
  users.users.ivsopi3.openssh.authorizedKeys.keys = [
    # TODO: add desktop's pubkey
  ];

  # ── Disk ─────────────────────────────────────────────────────────────
  # TODO: set EFI mount point and LUKS devices when installing
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.initrd.luks.devices."crypt_0" = {
  #   device = "/dev/disk/by-uuid/REPLACE-ME";
  #   preLVM = true;
  # };
}
