# Installation template: replace with the target server's generated hardware
# configuration, including its real filesystems, swap, and initrd drivers.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "ahci" "nvme" "xhci_pci" "usbhid" "usb_storage" "sd_mod" ];
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SERVER";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXOS_SERVER_BOOT";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
  swapDevices = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
