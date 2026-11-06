{ config, lib, pkgs, ... }:

let
  # Installation: temporarily set false to use router/Tailscale DNS before AdGuard runs.
  # Restore true once AdGuard answers DNS on 127.0.0.1, then rebuild.
  useAdguardDNS = true;
  # Installation: temporarily set false; restore true and rebuild before tailscale up.
  enableTailscale = true;
  lanInterface = "enp2s0";
  lanSubnet = "192.168.1.0/24";
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

  environment.systemPackages = with pkgs; [
    sbctl
    docker-compose
    dnsutils
    doggo
    ffmpeg-full
    restic
    btop
  ];

  system.stateVersion = "26.05";
}
