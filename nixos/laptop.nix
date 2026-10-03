{ config, lib, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  # ── Machine identity ────────────────────────────────────────────────
  networking.hostName = "ivX13";

  # ── SSH keys ────────────────────────────────────────────────────────
  # Who may ssh into this laptop. Migrated out of ~/.ssh/authorized_keys,
  # which sshd no longer reads (authorizedKeysInHomedir in configuration.nix).
  users.users.ivsopi3.openssh.authorizedKeys.keys = import ./trusted-ssh-keys.nix;

  # ── Disk ─────────────────────────────────────────────────────────────
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  boot.initrd.luks.devices."crypt_0" = {
    device = "/dev/disk/by-uuid/fdf5ac6a-f27e-4113-a33c-a71ff236b252";
    preLVM = true;
  };

  # ── Lid switch ───────────────────────────────────────────────────────
  # (services.logind.lidSwitch is the pre-rename spelling; it still works but
  # warns on every eval.) Power button is in configuration.nix.
  services.logind.settings.Login.HandleLidSwitch = "ignore";

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
