{ config, lib, pkgs, ... }:

{
  # ── Boot (lanzaboote / secure boot) ───────────────────────────────────
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── System tuning ────────────────────────────────────────────────────
  boot.kernel.sysctl."vm.swappiness" = 1;
  services.journald.extraConfig = "SystemMaxUse=100M";

  # ── Networking ────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  # ── Time / Locale ────────────────────────────────────────────────────
  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Nix settings ─────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ── Graphics (VM) ────────────────────────────────────────────────────
  hardware.graphics.enable = true;

  # ── Hyprland ──────────────────────────────────────────────────────────
  programs.hyprland.enable = true;

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

  # ── Bluetooth ────────────────────────────────────────────────────────
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };

  # ── Docker ───────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;

  # ── Firewall ─────────────────────────────────────────────────────────
  networking.firewall.checkReversePath = "loose";
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # ── Tailscale ────────────────────────────────────────────────────────
  services.tailscale.enable = true;

  # ── Libvirt / QEMU ──────────────────────────────────────────────────
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # ── User ──────────────────────────────────────────────────────────────
  users.users.ivsopi3 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "docker" "libvirtd" ];
  };

  # ── Shell ─────────────────────────────────────────────────────────────
  programs.zsh.enable = true;

  # ── GTK / Theming ────────────────────────────────────────────────────
  environment.variables = {
    GTK_THEME = "Adwaita:dark";
    QT_QPA_PLATFORM = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
    GDK_BACKEND = "wayland,x11";
    XCURSOR_SIZE = "24";
    EDITOR = "nvim";
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
        monospace = [ "JetBrainsMono Nerd Font" "DejaVu Sans Mono" ];
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

    # ─ Desktop ─
    dunst
    rofi
    networkmanagerapplet
    nemo-with-extensions
    pavucontrol
    desktop-file-utils
    gvfs

    # ─ Terminals ─
    alacritty
    kitty

    # ─ CLI essentials ─
    neovim
    delta
    tmux
    wget
    curl
    unzip
    zip
    file
    tree
    man-pages

    # ─ CLI tools ─
    eza
    bat
    fzf
    ripgrep
    fd
    jq
    pv
    zstd
    age
    gum
    chafa
    rsync
    psmisc
    gdu
    duf
    nethogs
    lazygit
    lazydocker
    claude-code
    yazi
    fend
    tldr
    gnupg
    sshfs
    netcat-openbsd
    w3m

    # ─ Wayland clipboard / utils ─
    wl-clipboard
    brightnessctl
    playerctl
    libnotify
    slurp
    grim
    hyprshot
    satty
    wayland-utils
    wlprop
    libsForQt5.qtwayland
    kdePackages.qtwayland

    # ─ Dev tools ─
    gcc
    gnumake
    cmake
    meson
    ninja
    pkg-config
    cpio
    rustup
    nodejs
    elixir
    python3
    typst
    gdb
    valgrind
    glew
    (vscode-with-extensions.override {
      vscodeExtensions = pkgs.nix4vscode.forVscode [
        "anthropic.claude-code"
        "astro-build.astro-vscode"
        "dtoplak.vscode-glsllint"
        "expertlsp.expert"
        "fwcd.kotlin"
        "ianandhum.protobuf-support"
        "ivsop.iana"
        "jeff-hykin.polacode-2019"
        "jgclark.vscode-todo-highlight"
        "llvm-vs-code-extensions.vscode-clangd"
        "ms-dotnettools.csdevkit"
        "ms-dotnettools.csharp"
        "ms-dotnettools.vscode-dotnet-runtime"
        "ms-python.debugpy"
        "ms-python.python"
        "ms-python.vscode-pylance"
        "ms-python.vscode-python-envs"
        "ms-toolsai.jupyter"
        "ms-toolsai.jupyter-keymap"
        "ms-toolsai.jupyter-renderers"
        "ms-toolsai.vscode-jupyter-cell-tags"
        "ms-toolsai.vscode-jupyter-slideshow"
        "ms-vscode.hexeditor"
        "ms-vsliveshare.vsliveshare"
        "myriad-dreamin.tinymist"
        "naumovs.color-highlight"
        "pgourlain.erlang"
        "polymeilex.wgsl"
        "raczzalan.webgl-glsl-editor"
        "redhat.java"
        "redhat.vscode-xml"
        "rickynormandeau.mariana-pro"
        "rust-lang.rust-analyzer"
        "slevesque.shader"
        "streetsidesoftware.code-spell-checker"
        "svelte.svelte-vscode"
        "tamasfe.even-better-toml"
        "tomoki1207.pdf"
        "vadimcn.vscode-lldb"
        "visualstudiotoolsforunity.vstuc"
        "vscjava.vscode-gradle"
        "vscjava.vscode-maven"
        "wakatime.vscode-wakatime"
      ];
    })
    renderdoc

    # ─ Hyprland plugin build deps ─
    hyprland.dev
    pixman
    libdrm
    pango
    libinput
    wayland
    libxkbcommon

    # ─ Waybar build deps ─
    wayland-scanner
    wayland-protocols
    gobject-introspection
    gtkmm3
    gtk-layer-shell
    gtk3
    glib
    glibmm
    cairomm
    pangomm
    libsigcxx
    jsoncpp
    fmt
    spdlog
    libnl
    libpulseaudio
    upower
    libevdev

    # ─ Media ─
    ffmpeg-full
    mpv
    ffmpegthumbnailer
    mediainfo
    imagemagick
    qpwgraph

    # ─ Apps ─
    discord
    obs-studio
    pinta
    inkscape
    kdePackages.kdenlive
    libresprite
    libreoffice
    blender
    qbittorrent
    pandoc

    # ─ Gaming ─
    lutris
    wine
    protontricks

    # ─ Virtualisation ─
    virt-viewer
    swtpm

    # ─ Databases ─
    mongodb-ce
    mongosh

    # ─ Backup / Sync ─
    restic
    backrest

    # ─ Network tools ─
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

  # ── Git ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user = {
        name = "Ivan Ribeiro";
        email = "ivan.ribeiro09s@gmail.com";
      };
      core = {
        editor = "nvim";
        pager = "delta";
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        dark = true;
      };
      merge.conflictstyle = "zdiff3";
      init.defaultBranch = "master";
      credential.helper = "cache";
      alias = {
        lg = "lg4";
        lg1 = "lg1-specific --all";
        lg2 = "lg2-specific --all";
        lg3 = "lg3-specific --all";
        lg4 = "log --graph --oneline --decorate --all";
        grhh = "reset --hard";
        nuke = "!git reset --hard && git clean -fdx";
        history = "!git log --color=always --oneline | fzf --reverse --multi --ansi --preview 'git show --color=always {+1}'";
        rank = "!git shortlog -n -s --no-merges | nl | grep --color -z -E 'Ivan Ribeiro|IVSOP'";
        review = "!git diff --name-only | fzf -m --ansi --preview 'git diff --color=always -- {-1}'";
        lg1-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'";
        lg2-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
        lg3-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)'";
      };
    };
  };

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
        "iron-wallet@naps62.com" = ext "ethui";
        "webextension@metamask.io" = ext "ether-metamask";
        "{7c42eea1-b3e4-4be4-a56f-82a5852b12dc}" = ext "phantom-app";
        "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = ext "refined-github-";
        "uBlock0@raymondhill.net" = ext "ublock-origin";
      };
      Preferences = {
        "browser.startup.page" = { Value = 3; Status = "locked"; };
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
}
