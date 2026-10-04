{ config, lib, pkgs, modulesPath, serverSource, ... }:

let
  firmware = pkgs.ubootRock4CPlus.overrideAttrs (old: {
    # Backport nixpkgs 86b713c6: dtc 1.8 rejects binman's @...-SEQ templates.
    postPatch = builtins.replaceStrings
      [ ''--replace-fail -Wno-graph_child_address ""'' ]
      [ ''--replace-fail -Wno-graph_child_address -Eno-node_name_not_empty'' ]
      old.postPatch;
  });
in {
  imports = [
    ./rock-server.nix
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  # sd-image.nix supplies image construction, not an interactive installer.
  hardware.enableAllHardware = lib.mkForce false;
  boot.supportedFilesystems = lib.mkForce [ "ext4" "vfat" ];
  # Bootstrap through a local root login, then set both passwords manually.
  # mutableUsers preserves passwd changes; server.nix forbids root/password SSH.
  users.users.root.initialHashedPassword = "";
  users.users.radxa.initialHashedPassword = "!";
  services.getty.helpLine = "Initial setup: log in locally as root (no password), run passwd root and passwd radxa, then log in as radxa and run sudo tailscale up.";

  sdImage = {
    rootVolumeLabel = "ROCK_SERVER";
    firmwarePartitionOffset = 16;
    firmwareSize = 8;
    populateFirmwareCommands = "";
    expandOnBoot = true;
    populateRootCommands = ''
      mkdir -p ./files/boot ./files/etc/nixos
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
      cp -r ${serverSource}/. ./files/etc/nixos/
      chmod -R u+w ./files/etc/nixos
    '';
    postBuildCommands = ''
      dd if=${firmware}/idbloader.img of="$img" bs=512 seek=64 conv=notrunc
      dd if=${firmware}/u-boot.itb of="$img" bs=512 seek=16384 conv=notrunc
    '';
  };
}
