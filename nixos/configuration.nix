{ config, lib, pkgs, nixpkgs-anchor, ... }:

let
  # Cross-compilation targets, installed for both toolchains.
  rustTargets = [
    "wasm32-unknown-unknown"   # wasm-bindgen / wasm-pack / wasm-server-runner
    "aarch64-linux-android"    # real ARM devices
    "x86_64-linux-android"     # emulator
    "x86_64-pc-windows-gnu"    # cross-linked via mingw-w64
  ];

  # Stable toolchain, minus rustfmt (nightly supplies that below).
  rustStable = pkgs.rust-bin.stable.latest.minimal.override {
    extensions = [ "rust-src" "rust-analyzer" "clippy" ];
    targets = rustTargets;
  };

  # Latest nightly that actually has all these components built.
  rustNightly = pkgs.rust-bin.selectLatestNightlyWith (toolchain:
    toolchain.default.override {
      extensions = [ "rust-src" "rustfmt" "clippy" ];
      targets = rustTargets;
    });

  # Native libraries C-sys crates need. Bevy (alsa/udev at build time, plus
  # vulkan/wayland/xkbcommon/X11 dlopened at runtime) is the driving case.
  rustNativeDeps = with pkgs; [
    alsa-lib
    systemdLibs      # libudev
    openssl
    libxkbcommon
    wayland
    vulkan-loader
    libGL            # libglvnd: gl.pc/egl.pc/glesv2.pc + libGL.so.1, libEGL.so.1
    libGLU
    libx11
    libxcursor
    libxi
    libxrandr
  ];

  # What lands on PATH by default: stable, with nightly rustfmt/cargo-fmt
  # so `cargo fmt` accepts nightly-only rustfmt.toml options.
  rustDefault = pkgs.runCommand "rust-default" { } ''
    mkdir -p $out/bin
    ln -s ${rustStable}/bin/* $out/bin/
    ln -sf ${rustNightly}/bin/rustfmt   $out/bin/rustfmt
    ln -sf ${rustNightly}/bin/cargo-fmt $out/bin/cargo-fmt
  '';

  # Full nightly toolchain as cargo-nightly, rustc-nightly, ...
  # PATH is prefixed so nightly cargo finds nightly rustc/rustfmt, not stable.
  rustNightlySuffixed = pkgs.runCommand "rust-nightly-suffixed"
    { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
    mkdir -p $out/bin
    for bin in ${rustNightly}/bin/*; do
      name=$(basename "$bin")
      makeWrapper "$bin" "$out/bin/$name-nightly" \
        --prefix PATH : ${rustNightly}/bin
    done
  '';

in

{
  imports = [ ./solana.nix ];

  # Consumed by solana.nix's rustup shim.
  _module.args = { inherit rustDefault rustNightly; };

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

  # ── Power button ─────────────────────────────────────────────────────
  # systemd's HandlePowerKey default is "poweroff"; suspend instead.
  services.logind.settings.Login.HandlePowerKey = "suspend";

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
  services.udev.packages = [ pkgs.brightnessctl ];

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

  # ssh-agent as a systemd user service, socket at $XDG_RUNTIME_DIR/ssh-agent.
  # Replaces the hand-rolled ssh-agent block that used to live in .zshrc:
  # this starts before the session, so graphical launches (hyprland keybinds,
  # .desktop entries) get SSH_AUTH_SOCK too, not just interactive shells.
  programs.ssh.startAgent = true;
  programs.ssh.agentTimeout = "3h";

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

  # ── Shell ─────────────────────────────────────────────────────────────
  programs.zsh.enable = true;

  # ── Foreign binaries (nix-ld) ─────────────────────────────────────────
  # Lets prebuilt, non-Nix binaries run: the Android NDK toolchain that
  # Android Studio's SDK Manager downloads into ~/Android/Sdk, pip wheels, etc.
  programs.nix-ld.enable = true;

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

  # ── Rust ──────────────────────────────────────────────────────────────
  # Linker + libpthread search path for the x86_64-pc-windows-gnu target.
  environment.variables.CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER =
    "${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc";
  environment.variables.CARGO_TARGET_X86_64_PC_WINDOWS_GNU_RUSTFLAGS =
    "-L ${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib";
  # cargo-examples / wasm-server-runner are not in nixpkgs; `cargo install` them.
  environment.sessionVariables.PATH = [ "$HOME/.cargo/bin" ];

  # pkg-config does not search /run/current-system/sw by default, so point it
  # straight at the dev outputs. Build-time only, so this is safe globally.
  environment.variables.PKG_CONFIG_PATH =
    lib.makeSearchPathOutput "dev" "lib/pkgconfig" rustNativeDeps;

  # Libraries that get dlopened at runtime (vulkan, wayland, xkbcommon, X11)
  # carry no RPATH, so they need a search path. Scoped to interactive shells
  # rather than set session-wide: a global LD_LIBRARY_PATH can break unrelated
  # Nix-built apps through library version skew.
  programs.zsh.interactiveShellInit = ''
    export LD_LIBRARY_PATH="${lib.makeLibraryPath rustNativeDeps}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  '';

  # ── Android ───────────────────────────────────────────────────────────
  # SDK and NDK are managed by Android Studio's SDK Manager, not by Nix,
  # so they live in a writable dir Studio can update. nix-ld (above) is what
  # makes the NDK's prebuilt clang runnable outside Studio's FHS sandbox.
  environment.sessionVariables.ANDROID_HOME = "$HOME/Android/Sdk";

  # Blank Swing windows under Hyprland. This is all android-studio's
  # `tiling_wm = true` override did, minus the rebuild.
  environment.sessionVariables._JAVA_AWT_WM_NONREPARENTING = "1";
  # cargo-ndk needs a concrete version dir; set once the NDK is installed:
  # environment.sessionVariables.ANDROID_NDK_HOME = "$HOME/Android/Sdk/ndk/<version>";

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

    # ─ Desktop ─
    dunst
    rofi
    networkmanagerapplet
    nemo-with-extensions
    pavucontrol
    desktop-file-utils
    waybar

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
    usbutils         # lsusb
    pciutils         # lspci

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
    swaybg                         # sway/scripts/set-bg.sh
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
    rustDefault
    rustNightlySuffixed
    cargo-edit
    cargo-expand
    wasm-bindgen-cli
    wasm-pack
    cargo-ndk                      # wires the NDK linker for android targets
    pkgsCross.mingwW64.stdenv.cc   # x86_64-w64-mingw32-gcc, linker for windows-gnu
    nodejs
    yarn                           # anchor test runner shells out to yarn
    python3
    typst
    fastfetch
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
    libavif                        # avifenc, the encoder sway/scripts/screenshot*.sh pipe into
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
    localsend

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

    # ─ Game / mobile dev ─
    unityhub
    # NB: no .override here. android-studio isn't on cache.nixos.org (unfree),
    # so any override forks the derivation into a 4 GB local rebuild fed by a
    # 1.3 GB source fetch. tiling_wm only sets _JAVA_AWT_WM_NONREPARENTING,
    # which sessionVariables does for free — see below.
    android-studio
    android-tools # adb/fastboot; programs.adb was removed (systemd 258 uaccess)

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
        editor = "code --wait";
        pager = "bat";
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

  # FHS shebang paths. NixOS ships only /bin/sh and /usr/bin/env, so scripts
  # written on Arch (where /bin is a symlink to /usr/bin) need the path they
  # actually name. Prefer `#!/usr/bin/env bash` in new scripts over growing
  # this list.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /usr/bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];
}
