{ config, lib, pkgs, ... }:

let
  # Installation: temporarily set false to use router/Tailscale DNS before AdGuard runs.
  # Restore true once AdGuard answers DNS on 127.0.0.1, then rebuild.
  useAdguardDNS = true;
  # Installation: temporarily set false; restore true and rebuild before tailscale up.
  enableTailscale = true;
  lanInterface = "enp2s0";
  lanSubnet = "192.168.1.0/24";
  # IT8613 temp1 thresholds, not CPU package temperatures. See docs/eq14-fan-curve.html.
  fanCurve = {
    # Live checks with off=45, start=50 and zero offset cycled near 44-46C.
    # Raise the off register too: target stop near 47C / resume near 50C.
    # Verified: stopped at 46C, stayed off at 47C, running again by 53C.
    # Exact switching boundaries and sustained-load cooling remain unverified.
    offTemperature = 50;
    startTemperature = 50;
    fullSpeedTemperature = 70;
    startPwm = 65;
    slope = 4; # PWM units per degree Celsius, not a response rate per second.
    # Additional chip offset in C: the absolute readback is offTemperature - hysteresis.
    # Restore a nonzero offset to reduce the zero-offset revision's cycling.
    hysteresis = 3;
    # No time delay, averaging window or spin-up/down time is exposed by this
    # controller's current Linux interface. pwm2_freq is the motor PWM carrier.
    # This curve uses temp1 only; it does not directly respond to SSD temperatures.
    # See the HTML for SSD readings, CPU power limits and remaining load checks.
  };
in
{
  imports = [ ./common.nix ./development.nix ./dotfiles.nix ];

  networking.hostName = lib.mkDefault "server";
  # Installation: use systemd-boot without Lanzaboote until signing keys exist.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  boot.loader.efi.efiSysMountPoint = lib.mkDefault "/boot/efi";
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = true;

  # The EQ14's IT8613E needs the extended it87 driver. Install under updates
  # so depmod prefers it over the kernel's bundled it87 module.
  boot.extraModulePackages = [
    (config.boot.kernelPackages.it87.overrideAttrs (old: {
      makeFlags = old.makeFlags ++ [
        "MODDESTDIR=$(out)/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/updates"
      ];
    }))
  ];
  boot.kernelModules = [ "it87" ];

  # Program the hardware's automatic controller; no userspace fan-control loop.
  systemd.services.eq14-fan-curve = {
    description = "Apply the EQ14 automatic fan curve";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    path = [ pkgs.coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      shopt -s nullglob
      controllers=()
      for device in /sys/class/hwmon/hwmon*; do
        if [[ "$(cat "$device/name")" == it8613 ]]; then
          controllers+=("$device")
        fi
      done
      if (( ''${#controllers[@]} != 1 )); then
        echo "Expected one IT8613 fan controller; found ''${#controllers[@]}" >&2
        exit 1
      fi
      device="''${controllers[0]}"
      if [[ "$(cat "$device/pwm2_enable")" != 2 || "$(cat "$device/pwm2_auto_channels_temp")" != 1 ]]; then
        echo "Expected PWM2 in automatic mode using temp1; refusing to change another setup" >&2
        exit 1
      fi

      # Apply stronger high-temperature cooling before delaying fan startup.
      printf '%s\n' ${toString (fanCurve.fullSpeedTemperature * 1000)} > "$device/pwm2_auto_point3_temp"
      printf '%s\n' ${toString fanCurve.startPwm} > "$device/pwm2_auto_start"
      printf '%s\n' ${toString (fanCurve.slope * 8)} > "$device/pwm2_auto_slope"
      printf '%s\n' ${toString (fanCurve.startTemperature * 1000)} > "$device/pwm2_auto_point2_temp"
      printf '%s\n' ${toString (fanCurve.offTemperature * 1000)} > "$device/pwm2_auto_point1_temp"
      printf '%s\n' ${toString ((fanCurve.offTemperature - fanCurve.hysteresis) * 1000)} > "$device/pwm2_auto_point1_temp_hyst"
      echo "Applied EQ14 automatic curve: off register ${toString fanCurve.offTemperature}C, ramp start ${toString fanCurve.startTemperature}C, full ${toString fanCurve.fullSpeedTemperature}C, hysteresis readback ${toString (fanCurve.offTemperature - fanCurve.hysteresis)}C"
    '';
  };

  hardware.graphics = {
    enable = true;
    # VA-API and OpenCL for native host applications; containers ship their own.
    extraPackages = with pkgs; [
      intel-media-driver
      intel-compute-runtime
    ];
  };

  users.users.ivsopi3 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    openssh.authorizedKeys.keys = import ./trusted-ssh-keys.nix;
    # Set the local login/sudo password during installation.
  };

  networking.useDHCP = false;
  networking.dhcpcd.enable = false;
  networking.networkmanager = {
    enable = true; # Includes nmcli and nmtui.
    dns = if useAdguardDNS then "none" else "default";
    unmanaged = [ "interface-name:tailscale0" "interface-name:docker0" "interface-name:br-*" ];
    # Do not create DHCP profiles for otherwise unconfigured Ethernet ports.
    settings.main.no-auto-default = "*";
    ensureProfiles.profiles.server-lan = {
      connection = {
        id = "server-lan";
        type = "ethernet";
        interface-name = lanInterface;
        autoconnect = true;
      };
      ipv4 = {
        method = "manual";
        address1 = "192.168.1.228/24";
        gateway = "192.168.1.1";
        dns = if useAdguardDNS then "127.0.0.1;" else "192.168.1.1;";
        ignore-auto-dns = true;
      };
      ipv6.method = "auto";
    };
  };
  networking.nameservers = lib.optionals useAdguardDNS [ "127.0.0.1" ];
  # Expand short Tailscale names; AdGuard forwards this domain to 100.100.100.100.
  networking.search = lib.optionals useAdguardDNS [ "tail122f46.ts.net" ];
  hardware.bluetooth = {
    enable = true; # Includes bluez/bluetoothctl.
    powerOnBoot = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    authorizedKeysInHomedir = false;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey";
    };
  };
  services.tailscale = {
    enable = enableTailscale;
    openFirewall = true; # UDP transport for direct peer connections only.
    useRoutingFeatures = "none";
    extraSetFlags = [ "--accept-dns=${if useAdguardDNS then "false" else "true"}" ];
    # Authenticate once with sudo tailscale up; state survives reboot.
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    logDriver = "local";
    daemon.settings.log-opts = {
      max-size = "10m";
      max-file = "3";
    };
  };

  # Compose creates stack networks; bootstrap only the shared external one.
  systemd.services.docker-proxy-network = {
    description = "Ensure the shared Docker proxy network exists";
    wantedBy = [ "docker.service" ];
    requires = [ "docker.service" ];
    after = [ "docker.service" ];
    partOf = [ "docker.service" ];
    path = [ config.virtualisation.docker.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if ! docker network inspect proxy >/dev/null 2>&1; then
        docker network create \
          --driver bridge \
          --subnet 172.18.0.0/16 \
          --gateway 172.18.0.1 \
          proxy
      fi
    '';
  };
  systemd.tmpfiles.rules = [
    "d /services/traefik/certs 0700 root root -"
  ];

  networking.firewall = {
    enable = true;
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };
  networking.nftables = {
    enable = true;
    # Preserve Docker's and Tailscale's independently managed tables on reload.
    flushRuleset = false;
    tables.docker-ingress = {
      family = "inet";
      content = ''
        chain forward {
          type filter hook forward priority -10; policy accept;
          ct state established,related accept
          iifname { "tailscale0", "lo", "docker0" } accept
          iifname "br-*" accept
          # AdGuard serves household DNS; the host can use its loopback binding.
          iifname "${lanInterface}" ip saddr ${lanSubnet} ct status dnat tcp dport 53 ct original proto-dst 53 counter accept
          iifname "${lanInterface}" ip saddr ${lanSubnet} ct status dnat udp dport 53 ct original proto-dst 53 counter accept
          # Incoming torrent peers, including connections forwarded by the router.
          iifname "${lanInterface}" ct status dnat tcp dport 6881 ct original proto-dst 6881 counter accept
          iifname "${lanInterface}" ct status dnat udp dport 6881 ct original proto-dst 6881 counter accept
          # Published container ports bypass INPUT after DNAT.
          ct status dnat counter drop
          # Block direct routing from physical interfaces into Docker too.
          oifname "docker0" counter drop
          oifname "br-*" counter drop
        }
      '';
    };
  };
  systemd.services.docker = {
    requires = [ "nftables.service" ];
    after = [ "nftables.service" ];
  };

  # Keep an unattended server awake.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
    suspend-then-hibernate.enable = false;
  };

  # Allow wheel members to read CPU energy and Intel GPU performance counters.
  security.wrappers.btop = {
    source = "${pkgs.btop}/bin/btop";
    owner = "root";
    group = "wheel";
    permissions = "u+rx,g+rx,o-rwx";
    capabilities = "cap_perfmon,cap_dac_read_search+ep";
  };

  environment.systemPackages = with pkgs; [
    sbctl
    docker-compose
    dnsutils
    doggo
    ffmpeg-full
    restic
    btop
    lm_sensors
  ];

  system.stateVersion = "26.05";
}
