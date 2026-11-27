{ pkgs, ... }:

{
  imports = [
    ../../modules/dotfiles.nix
    ../../profiles/workstation
    ../../profiles/x86-base.nix
    ../../modules/development.nix
    ./hardware-configuration.nix
  ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "IVPC";
  system.stateVersion = "26.05";

  environment.systemPackages = with pkgs; [
    ckan
    vintagestory
  ];

  # ── SSH keys ────────────────────────────────────────────────────────
  # Shared with the laptop and server.
  users.users.ivsopi3.openssh.authorizedKeys.keys = import ../../trusted-ssh-keys.nix;

  # ── Disk ─────────────────────────────────────────────────────────────
  # Set to false for a fresh install until Secure Boot signing keys exist.
  boot.lanzaboote.enable = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.initrd.luks.devices = {
    crypt_0.device = "/dev/disk/by-uuid/1dff8699-bbc7-4326-bc92-0d919789a272";
    crypt_1.device = "/dev/disk/by-uuid/79a9d887-ffd8-4ae8-a27c-ac48b053204f";
  };
}
