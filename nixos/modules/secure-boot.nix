{ inputs, lib, ... }:

{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  # Installation uses systemd-boot until the signing keys are in place.
  boot.loader.systemd-boot.enable = lib.mkForce true;
  boot.lanzaboote = {
    enable = false;
    pkiBundle = "/var/lib/sbctl";
  };
}
