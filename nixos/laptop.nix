{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "ivX13";

  # ── SSH keys ────────────────────────────────────────────────────────
  users.users.ivsopi3.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB8h1FmwwaSRrhw+l9p70ORPfT7vCt5vp/sWzv+BU6rp ivan.ribeiro09s@gmail.com"
  ];

  # ── Disk ─────────────────────────────────────────────────────────────
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.initrd.luks.devices."crypt_0" = {
    device = "/dev/disk/by-uuid/c520eec8-3e1b-4e3b-a0e5-ce9f38426477";
    preLVM = true;
  };

  # ── Lid switch ───────────────────────────────────────────────────────
  services.logind.lidSwitch = "ignore";

  # ── TLP (power management) ─────────────────────────────────────────
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      CPU_MIN_PERF_ON_AC = 0;
      CPU_MAX_PERF_ON_AC = 100;
      CPU_MIN_PERF_ON_BAT = 0;
      CPU_MAX_PERF_ON_BAT = 70;

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      CPU_HWP_DYN_BOOST_ON_AC = 1;
      CPU_HWP_DYN_BOOST_ON_BAT = 0;

      PLATFORM_PROFILE_ON_AC = "performance";
      PLATFORM_PROFILE_ON_BAT = "power";

      START_CHARGE_THRESH_BAT0 = 55;
      STOP_CHARGE_THRESH_BAT0 = 60;
    };
  };

  environment.etc."tlp.d/01-powersave-BAT.conf".text = ''
    CPU_ENERGY_PERF_POLICY_ON_BAT=power
    CPU_SCALING_GOVERNOR_ON_BAT=powersave
    CPU_MIN_PERF_ON_BAT=0
    CPU_MAX_PERF_ON_BAT=70
    CPU_BOOST_ON_BAT=0
    CPU_HWP_DYN_BOOST_ON_BAT=0
    PLATFORM_PROFILE_ON_BAT=power
    STOP_CHARGE_THRESH_BAT0=1
  '';

  environment.etc."tlp.d/04-balanced-AC.conf".text = ''
    CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
    CPU_SCALING_GOVERNOR_ON_AC=performance
    CPU_MIN_PERF_ON_AC=0
    CPU_MAX_PERF_ON_AC=100
    CPU_BOOST_ON_AC=1
    CPU_HWP_DYN_BOOST_ON_AC=1
    PLATFORM_PROFILE_ON_AC=balance_performance
  '';
}
