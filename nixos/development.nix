# One development environment for the desktop, laptop, and regular server.
{ lib, pkgs, ... }:

let
  # Cross-compilation targets, installed for both toolchains.
  rustTargets = [
    "wasm32-unknown-unknown"   # wasm-bindgen / wasm-pack / wasm-server-runner
    "aarch64-linux-android"    # real ARM devices
    "aarch64-unknown-linux-musl" # ROCK 4C+ static Linux binaries
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

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # ── Foreign binaries (nix-ld) ─────────────────────────────────────────
  # Lets prebuilt, non-Nix binaries run: the Android NDK toolchain that
  # Android Studio's SDK Manager downloads into ~/Android/Sdk, pip wheels, etc.
  programs.nix-ld.enable = true;

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

  environment.systemPackages = with pkgs; [
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
    postgresql
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

    # ─ Databases ─
    mongodb-ce
    mongosh

    # ─ Game / mobile dev ─
    unityhub
    # NB: no .override here. android-studio isn't on cache.nixos.org (unfree),
    # so any override forks the derivation into a 4 GB local rebuild fed by a
    # 1.3 GB source fetch. tiling_wm only sets _JAVA_AWT_WM_NONREPARENTING,
    # which the shared sessionVariables set above.
    android-studio
    android-tools # adb/fastboot; programs.adb was removed (systemd 258 uaccess)
  ];
}
