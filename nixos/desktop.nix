{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "IVPC";

  # ── SSH keys ────────────────────────────────────────────────────────
  # Same allow-list as laptop.nix (ivX13); keep the two in sync.
  users.users.ivsopi3.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8h1FmwwaSRrhw+l9p70ORPfT7vCt5vp/sWzv+BU6rp"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHr6tri60BW34m2Q9uiqP8o0nVN9KPr+CiWtg+7MC2X/"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIr04H7PY/Sdz4vmxulM0kwTxkjOaVpFvj5alQrELrmG"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIujn2OWfYXYNdj1m6wQxLMC4p25a9htzbX0v9eK22i2"
    # Unidentified — carried over from the old authorized_keys file. Prune
    # whichever machine you no longer recognise.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfjiOwuaUi4cDji9xiUSKCaTMJNXWkCsQk7T/XE+RYt"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIozjRvmEooF6PlNEQBJzAVP694QgIQUZImQGBj1OF63"
  ];

  # ── Disk ─────────────────────────────────────────────────────────────
  # TODO: set EFI mount point and LUKS devices when installing
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.initrd.luks.devices."crypt_0" = {
  #   device = "/dev/disk/by-uuid/REPLACE-ME";
  #   preLVM = true;
  # };
}
