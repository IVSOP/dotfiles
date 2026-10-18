{ config, lib, pkgs, ... }:

{
  imports = [ ./common.nix ./development.nix ./dotfiles.nix ];

  networking.hostName = lib.mkDefault "server";
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
  hardware.enableRedistributableFirmware = true;

  users.users.ivsopi3 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    openssh.authorizedKeys.keys = import ./trusted-ssh-keys.nix;
    # Set the local login/sudo password during installation.
  };

  networking.networkmanager = {
    enable = true; # Includes nmcli and nmtui.
    unmanaged = [ "interface-name:tailscale0" "interface-name:docker0" "interface-name:br-*" ];
  };
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
    enable = true;
    openFirewall = true; # UDP transport for direct peer connections only.
    useRoutingFeatures = "none";
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
    docker-compose
    dnsutils
    doggo
    ffmpeg-full
    restic
    btop
  ];

  system.stateVersion = "26.05";
}
