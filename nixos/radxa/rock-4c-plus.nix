{ lib, pkgs, ... }:

{
  imports = [ ./radxa-defaults.nix ];
  nixpkgs.hostPlatform = "aarch64-linux";
  nixpkgs.config.allowUnfreePredicate = pkg:
    lib.getName pkg == "arm-trusted-firmware-rk3399";
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;
  boot.kernelPackages = pkgs.linuxPackages;
  hardware.deviceTree.enable = true;
  hardware.deviceTree.name = "rockchip/rk3399-rock-4c-plus.dtb";
  boot.kernelParams = [ "console=ttyS2,1500000n8" "console=tty0" ];
  boot.initrd.availableKernelModules = [
    "rockchip_rga" "rockchip_saradc" "rockchip_thermal"
    # Storage power rails may depend on modular I2C/PMIC drivers.
    "i2c_rk3x" "rk8xx_i2c" "rk808_regulator" "fan53555"
    "dw_mmc_rockchip" "sdhci_of_arasan" "sdhci_pltfm"
    "phy_rockchip_emmc" "phy_rockchip_pcie" "pcie_rockchip_host"
    # Include the USB controllers and PHYs when installing onto a USB card reader.
    "phy_rockchip_inno_usb2" "phy_rockchip_typec"
    "dwc3" "dwc3_of_simple" "usb_storage" "uas"
    "xhci_pci" "xhci_platform" "ehci_platform" "ohci_platform"
  ];

  # gpio-cdev 0.6 in the Rust counter uses character-device API v1.
  # Modern kernels may disable it by default. Build this on the fast host.
  boot.kernelPatches = [ {
    name = "gpio-character-device-compatibility";
    patch = null;
    structuredExtraConfig = with lib.kernel; {
      GPIO_CDEV = yes;
      GPIO_CDEV_V1 = yes;
    };
  } ];
}
