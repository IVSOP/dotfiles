{ inputs, lib, pkgs, ... }:

{
  imports = [
    ./session.nix
    ./services.nix
    ../../modules/obsidian.nix
    (import ../../modules/docker-credentials.nix { backend = "secretservice"; })
    inputs.steam-controller-status.nixosModules.default
  ];

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
    glib.bin # gio command-line tools
    android-file-transfer          # aft-mtp-mount / aft-mtp-cli
    file-roller
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
    # libavif's pixbuf loader rejects valid AVIFs with a 28-byte ftyp box.
    # Override its thumbnailer with FFmpeg, which handles those files too.
    (lib.hiPrio (pkgs.writeTextDir "share/thumbnailers/avif.thumbnailer" ''
      [Thumbnailer Entry]
      TryExec=${pkgs.ffmpegthumbnailer}/bin/ffmpegthumbnailer
      Exec=${pkgs.ffmpegthumbnailer}/bin/ffmpegthumbnailer -i %i -o %o -s %s -t 0
      MimeType=image/avif;
    ''))
    mpv
    ffmpegthumbnailer              # Nemo previews for MP4, MKV, WebM, etc.
    mediainfo
    imagemagick
    qpwgraph

    # ─ Apps ─
    dbeaver-bin
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

    # ─ Gaming ─
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
  programs.steam = {
    enable = true;
    extest.enable = true;
  };

  # The Hyprland startup hook starts the applet alongside Solaar.
  programs.steam-controller-status = {
    enable = true;
    autostart = false;
  };

  # ── Nemo defaults ────────────────────────────────────────────────────
  # Nemo reads org.cinnamon.desktop.default-applications.terminal, whose
  # schema default is gnome-terminal (not installed) — so the menu item
  # silently did nothing.
  programs.dconf = {
    enable = true;
    profiles.user.databases = [{
      settings."org/cinnamon/desktop/applications/terminal".exec = "alacritty";
      settings."org/nemo/preferences" = {
        show-hidden-files = true;
        show-image-thumbnails = "local-only";
        # Nemo shares this limit across images and videos; allow up to 10 GiB.
        thumbnail-limit = lib.gvariant.mkUint64 (10 * 1024 * 1024 * 1024);
      };
    }];
  };
}
