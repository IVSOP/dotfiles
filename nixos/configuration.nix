{ lib, pkgs, ... }:

{
  imports = [ ./common.nix ./development.nix ./obsidian.nix ];

  # ── Boot (lanzaboote / secure boot) ───────────────────────────────────
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # ── Networking ────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  # ── Power button ─────────────────────────────────────────────────────
  # systemd's HandlePowerKey default is "poweroff"; suspend instead.
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # ── Graphics (VM) ────────────────────────────────────────────────────
  hardware.graphics.enable = true;

  # ── Hyprland ──────────────────────────────────────────────────────────
  programs.hyprland.enable = true;

  environment.etc."hypr/libhy3.so".source = "${pkgs.hy3}/lib/libhy3.so";

  # ly display manager
  services.displayManager.ly.enable = true;

  # XDG portal for screen sharing, file dialogs, etc.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };

  # ── Audio (PipeWire) ─────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ── udev rules from packages ─────────────────────────────────────────
  # systemPackages only puts binaries on PATH; a package's udev rules are
  # ignored unless listed here. brightnessctl ships 90-brightnessctl.rules,
  # which chgrps /sys/class/backlight/*/brightness to the video group and
  # adds group-write — without it the XF86MonBrightness binds can't write
  # to the backlight (file stays root:root 644).
  services.udev.packages = [ pkgs.brightnessctl pkgs.logitech-udev-rules ];

  # ── Removable media ──────────────────────────────────────────────────
  # Nemo's drive sidebar is gvfs talking to udisks2 over D-Bus. gvfs in
  # systemPackages only installs binaries; the daemon needs the module,
  # and without udisks2 the volume monitor has nothing to enumerate.
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # ── Bluetooth ────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────
  services.openssh.enable = true;
  # Defaults to true, which would open 22 on every interface. The firewall
  # section below opens it on tailscale0 only.
  services.openssh.openFirewall = false;
  # Fully manual: `systemctl start sshd`. Not socket-activated — that would
  # still leave systemd listening on 22 from boot.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  # Drop %h/.ssh/authorized_keys from AuthorizedKeysFile, leaving only
  # /etc/ssh/authorized_keys.d/%u, which nix generates read-only. Keys are
  # then declared per host (laptop.nix / desktop.nix) and nowhere else — a
  # key dropped into a home dir by hand no longer grants access.
  services.openssh.authorizedKeysInHomedir = false;

  # ── Docker ───────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  # Fully manual: `systemctl start docker`. enableOnBoot drops dockerd from
  # multi-user.target; the socket has to be pulled out of sockets.target too,
  # or the first `docker` command would activate the daemon on demand.
  # docker.service Requires=docker.socket, so starting the service still
  # brings the socket up. `--restart=always` containers only return on start.
  virtualisation.docker.enableOnBoot = false;
  systemd.sockets.docker.wantedBy = lib.mkForce [ ];

  # ── Firewall ─────────────────────────────────────────────────────────
  # NixOS' own firewall (nftables backend), not ufw. Input policy is drop and
  # nothing is opened globally; SSH is reachable over tailscale0 only.
  # Outbound traffic is never filtered, so there is no "allow out" to write.
  # Temporary holes: `sudo nixos-firewall-tool open tcp 8888` / `... reset`.
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";        # required by tailscale
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    interfaces."tailscale0".allowedTCPPorts = [ 22 ];
  };

  # ── Tailscale ────────────────────────────────────────────────────────
  services.tailscale.enable = true;
  # tailscaled ships no socket unit, so this one is genuinely manual:
  # `tup` / `tdown` (systemctl start/stop tailscaled). State is preserved,
  # so it reconnects on start without re-running `tailscale up`.
  systemd.services.tailscaled.wantedBy = lib.mkForce [ ];
  # Opens UDP 41641 so peers can connect directly; without it tailscale still
  # works but every connection is bounced through a DERP relay.
  services.tailscale.openFirewall = true;

  # ── Libvirt / QEMU ──────────────────────────────────────────────────
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # Fully manual: `systemctl start libvirtd`. Socket out of sockets.target as
  # well, otherwise virsh/virt-manager would activate the daemon on demand.
  # libvirtd.service Wants its sockets, so starting it brings them up.
  # libvirt-guests (VM autostart/suspend at boot and shutdown) is pointless
  # with no daemon at boot, so it goes too.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
  systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];
  systemd.sockets.libvirtd.wantedBy = lib.mkForce [ ];
  # virtlogd/virtlockd are the helper daemons' sockets, and unlike the three
  # libvirtd ones they sit in sockets.target, so they were still being opened
  # at boot ("Listening on Virtual machine log/lock manager socket"). They cost
  # nothing and start no daemon, but they are the only libvirt noise left in a
  # boot log. libvirtd.service Requires=virtlogd.socket and Wants=virtlockd.socket,
  # so `systemctl start libvirtd` still pulls both up.
  systemd.sockets.virtlogd.wantedBy = lib.mkForce [ ];
  systemd.sockets.virtlockd.wantedBy = lib.mkForce [ ];

  # ── User ──────────────────────────────────────────────────────────────
  users.users.ivsopi3 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" "libvirtd" ];
  };

  # ── GTK / Theming ────────────────────────────────────────────────────
  environment.variables = {
    GTK_THEME = "Adwaita:dark";
    QT_QPA_PLATFORM = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland,x11";
    XCURSOR_SIZE = "24";
  };

  # ── Cursor ────────────────────────────────────────────────────────────
  environment.sessionVariables.XCURSOR_THEME = "Adwaita";

  # ── Fonts ─────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      cantarell-fonts
      dejavu_fonts
      liberation_ttf
      freefont_ttf
      ibm-plex
    ];
    fontconfig = {
      antialias = true;
      defaultFonts = {
        monospace = [ "Noto Sans Mono" "JetBrainsMono Nerd Font" "DejaVu Sans Mono" ];
        sansSerif = [ "Cantarell" "DejaVu Sans" ];
        serif = [ "DejaVu Serif" ];
      };
    };
  };

  # ── System packages ──────────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    # ─ Hyprland ecosystem ─
    hyprpaper
    hypridle
    hyprlock
    hyprsunset
    hyprpicker
    hyprmoncfg

    # ─ Desktop ─
    dunst
    rofi
    networkmanagerapplet
    nemo-with-extensions
    pavucontrol
    desktop-file-utils
    waybar
    google-chrome

    # ─ Terminals ─
    alacritty

    # ─ Wayland clipboard / utils ─
    wl-clipboard
    wl-clip-persist
    brightnessctl
    playerctl
    libnotify
    slurp
    grim
    hyprshot
    satty
    swaybg                         # sway/scripts/set-bg.sh
    wayland-utils
    wlprop
    libsForQt5.qtwayland
    kdePackages.qtwayland

    # ─ Media ─
    ffmpeg-full
    libavif                        # avifenc, the encoder sway/scripts/screenshot*.sh pipe into
    mpv
    ffmpegthumbnailer
    mediainfo
    imagemagick
    qpwgraph

    # ─ Apps ─
    telegram-desktop
    discord
    obs-studio
    obsidian
    pinta
    inkscape
    kdePackages.kdenlive
    libresprite
    libreoffice
    blender
    qbittorrent
    pandoc
    localsend

    # ─ Gaming ─
    lutris
    wineWow64Packages.stable
    protontricks

    # ─ Virtualisation ─
    virt-viewer
    swtpm

    # ─ Backup / Sync ─
    restic
    backrest

    # ─ Network tools ─
    dnsutils # dig, nslookup, host, nsupdate
    doggo    # Modern DNS client with DoH and DoT support
    somo
    cloudflare-warp
    tailscale

    # ─ System monitoring ─
    htop
    btop
    amdgpu_top

    # ─ Encryption / Security ─
    veracrypt

    # ─ Misc ─
    adwaita-icon-theme
    solaar
    wdisplays
    sbctl
  ];

  # ── Firefox ──────────────────────────────────────────────────────────
  programs.firefox = {
    enable = true;
    policies = {
      ExtensionSettings = let
        ext = slug: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          installation_mode = "force_installed";
        };
      in {
        "addon@darkreader.org" = ext "darkreader";
        "{47a97a22-13b8-410a-9bd8-2bf689498872}" = ext "perfectdarktheme";
        "iron-wallet@naps62.com" = ext "ethui";
        "webextension@metamask.io" = ext "ether-metamask";
        "{7c42eea1-b3e4-4be4-a56f-82a5852b12dc}" = ext "phantom-app";
        "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = ext "refined-github-";
        "uBlock0@raymondhill.net" = ext "ublock-origin";
      };
      Preferences = {
        # Restore the previous session on startup.
        "browser.startup.page" = { Value = 3; Status = "locked"; };
        # Open new tabs immediately to the right of the current one.
        "browser.tabs.insertAfterCurrent" = { Value = true; Status = "locked"; };
        # Keep web content dark alongside the installed browser theme.
        "layout.css.prefers-color-scheme.content-override" = { Value = 0; Status = "locked"; };
      };
    };
  };

  # ── Steam ────────────────────────────────────────────────────────────
  programs.steam.enable = true;

  # ── Security (sudo) ──────────────────────────────────────────────────
  security.polkit.enable = true;

  # Let hyprlock verify passwords
  security.pam.services.hyprlock = {};

  # ── stateVersion ─────────────────────────────────────────────────────
  system.stateVersion = "26.05";

  # ── Nemo defaults ────────────────────────────────────────────────────
  # Nemo reads org.cinnamon.desktop.default-applications.terminal, whose
  # schema default is gnome-terminal (not installed) — so the menu item
  # silently did nothing.
  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings."org/cinnamon/desktop/applications/terminal".exec = "alacritty";
      settings."org/nemo/preferences".show-hidden-files = true;
    }];
  };
}
