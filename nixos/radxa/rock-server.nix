{ lib, pkgs, ... }:

{
  imports = [ ./server.nix ./rock-4c-plus.nix ];

  # The flashed image uses this root label; no per-board UUID edits needed.
  fileSystems."/" = {
    device = "/dev/disk/by-label/ROCK_SERVER";
    fsType = "ext4";
  };
  swapDevices = [ ];
}
