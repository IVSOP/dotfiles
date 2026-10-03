{ lib, pkgs, ... }:

{
  # Standalone server policy: deliberately does not import configuration.nix.
  networking.hostName = lib.mkDefault "rock-server";
  time.timeZone = "Europe/Lisbon";

  users.mutableUsers = true; # passwd changes survive rebuilds and reboots.
  users.users.ivsopi3 = {
    isNormalUser = true;
    extraGroups = [
      "wheel" "docker" "networkmanager" "lp" "dialout"
      "audio" "video" "render" "plugdev" "gpio" "i2c" "spidev" "pwm"
    ];
    openssh.authorizedKeys.keys = import ../trusted-ssh-keys.nix;
    # No password in the Nix store. Set it during installation.
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
    openFirewall = false; # Outbound connections/relays work; no public UDP hole.
    useRoutingFeatures = "none";
    # No authKeyFile: run sudo tailscale up once, state survives reboots.
  };

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    daemon.settings = {
      log-driver = "local";
      log-opts = {
        max-size = "10m";
        max-file = "3";
      };
    };
  };

  networking.firewall = {
    enable = true;
    allowPing = false;
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
  };
  networking.nftables = {
    enable = true;
    # Never flush Docker's or Tailscale's independently managed tables.
    flushRuleset = false;
    tables.docker-ingress = {
      family = "inet"; # Covers IPv4 and IPv6.
      content = ''
        chain forward {
          type filter hook forward priority -10; policy accept;
          ct state established,related accept
          iifname { "tailscale0", "lo", "docker0" } accept
          iifname "br-*" accept
          # Published ports are DNATed before INPUT; guard them here.
          ct status dnat counter drop
          # Also prevent direct routing to standard Docker bridge networks.
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

  environment.defaultPackages = [ ];
  environment.systemPackages = [ pkgs.docker-compose ];
  documentation.enable = false;
  programs.command-not-found.enable = false;
  services.journald.settings.Journal = {
    SystemMaxUse = "64M";
    RuntimeMaxUse = "16M";
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  system.stateVersion = "26.05";
}
