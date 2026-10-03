{ config, lib, pkgs, ... }:

let
  pwmPermissions = pkgs.writeShellScript "radxa-pwm-permissions" ''
    set -eu
    pwm_path="$1"
    # Apply to both the chip and channels created later by writing export.
    for entry in "$pwm_path" "$pwm_path"/export "$pwm_path"/unexport \
      "$pwm_path"/pwm* "$pwm_path"/pwm*/*; do
      if [ -e "$entry" ]; then
        ${pkgs.coreutils}/bin/chgrp pwm "$entry"
        ${pkgs.coreutils}/bin/chmod g+rwX "$entry"
      fi
    done
  '';
in {
  # Ported from radxa-system-config 263af2c8 and radxa-udev.
  # Kept separate from server policy so the installer gets hardware support too.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
  boot.kernel.sysctl = {
    "vm.vfs_cache_pressure" = 500;
    "vm.swappiness" = 100;
    "vm.dirty_background_ratio" = 1;
    "vm.dirty_ratio" = 50;
    "vm.min_free_kbytes" = 16384;
    "vm.max_map_count" = 1048576;
  };

  # Keep the modern NixOS governor; Radxa's older tuning is opt-in.
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
  systemd.services.radxa-ondemand-tuning = lib.mkIf (
    config.powerManagement.cpuFreqGovernor == "ondemand"
  ) {
    description = "Radxa ondemand governor tuning";
    requires = [ "cpufreq.service" ];
    after = [ "cpufreq.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionVirtualization = false;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Kernels can expose global or per-policy governor attributes.
      for governor in /sys/devices/system/cpu/cpufreq/ondemand \
        /sys/devices/system/cpu/cpufreq/policy*/ondemand; do
        [ -d "$governor" ] || continue
        printf '%s\n' 1 > "$governor/io_is_busy"
        printf '%s\n' 10 > "$governor/sampling_down_factor"
        printf '%s\n' 200000 > "$governor/sampling_rate"
        printf '%s\n' 25 > "$governor/up_threshold"
      done
    '';
  };
  services.irqbalance.enable = true;
  # RK3399: Radxa directs interrupts away from the four LITTLE cores.
  systemd.services.irqbalance.environment.IRQBALANCE_BANNED_CPULIST = "0-3";

  networking.useDHCP = lib.mkDefault false; # NetworkManager owns DHCP.
  networking.dhcpcd.enable = false;
  networking.networkmanager = {
    enable = true;
    wifi.scanRandMacAddress = false;
    # Leave virtual networks managed by Docker and Tailscale alone.
    unmanaged = [ "interface-name:tailscale0" "interface-name:docker0" "interface-name:br-*" ];
  };
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  hardware.wirelessRegulatoryDatabase = true;
  hardware.firmware = [ (pkgs.callPackage ./rock-wireless-firmware.nix { }) ];
  services.timesyncd.enable = true;
  # Same intent as Radxa's disable-sleep package for unattended systems.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    suspend-then-hibernate.enable = false;
  };

  users.groups = {
    gpio = { };
    i2c = { };
    spidev = { };
    pwm = { };
    plugdev = { };
    render = { };
  };
  boot.kernelModules = [
    "i2c-dev"
    "ledtrig-default-on" "ledtrig-heartbeat" "ledtrig-pattern"
    "ledtrig-timer" "ledtrig-disk" "ledtrig-netdev"
  ];
  services.udev.extraRules = ''
    SUBSYSTEM=="gpio", KERNEL=="gpiochip*", ACTION=="add|change", GROUP="gpio", MODE="0660"
    SUBSYSTEM=="i2c-dev", KERNEL=="i2c-*", ACTION=="add|change", GROUP="i2c", MODE="0660"
    SUBSYSTEM=="spidev", KERNEL=="spidev*", ACTION=="add|change", GROUP="spidev", MODE="0660"
    SUBSYSTEM=="pwm", ACTION=="add|change", RUN+="${pwmPermissions} /sys$devpath"
  '';
  systemd.services."serial-getty@".environment.TERM = "linux";
}
