{ inputs, pkgs, ... }:

let
  inherit (import ./overlays.nix inputs) hy3Overlay;
in
{
  nixpkgs.overlays = [ hy3Overlay ];
  boot.loader.efi.canTouchEfiVariables = true;

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
    # programs.hyprland provides the matching Hyprland portal.
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
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

  # Start GVfs before removable drives are connected during the session.
  systemd.user.targets.graphical-session = {
    overrideStrategy = "asDropin";
    wants = [ "gvfs-udisks2-volume-monitor.service" ];
  };

  # ── Bluetooth ────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

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
      source-sans-pro
      roboto
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

  # ── Security (sudo) ──────────────────────────────────────────────────
  security.polkit.enable = true;

  # Let hyprlock verify passwords
  security.pam.services.hyprlock = {};
}
