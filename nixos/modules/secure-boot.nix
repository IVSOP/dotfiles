{ config, inputs, lib, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # Fresh installs can disable signing in the host configuration until keys exist.
  boot.loader.systemd-boot.enable = lib.mkForce (!config.boot.lanzaboote.enable);
  boot.lanzaboote.enable = lib.mkDefault true;
  boot.lanzaboote.pkiBundle = "/var/lib/sbctl";
}
