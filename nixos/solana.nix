# Solana/anchor toolchain. Versions are pinned because Anchor.toml pins
# them and the CLI aborts on a mismatch rather than warning.
{ pkgs, nixpkgs-anchor, rustDefault, rustNightly, ... }:

let
  # 1.0.2, from the last nixpkgs that packaged it; this system's nixpkgs
  # ships 1.1.2. Imported bare, without the system's overlays.
  anchorPinned = pkgs.symlinkJoin {
    name = "anchor-1.0.2";
    paths = [ (import nixpkgs-anchor { inherit (pkgs.stdenv.hostPlatform) system; }).anchor ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/anchor --prefix PATH : ${rustupShim}/bin
    '';
  };

  solanaCli = pkgs.solana-cli;

  # anchor and cargo-build-sbf assume rustup, which can't go in
  # systemPackages (cargo/rustc collide with rustDefault). Dispatches per
  # call; rustc is shimmed too because rustup's cargo proxy sets
  # RUSTUP_TOOLCHAIN and then expects a matching rustc proxy on PATH.
  rustupShim = pkgs.runCommand "solana-rustup-shim" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.rustup}/bin/rustup $out/bin/rustup

    cat > $out/bin/cargo <<SHIM
    #!${pkgs.runtimeShell}
    case "\$1" in
      +stable)  shift; exec ${rustDefault}/bin/cargo "\$@" ;;
      +nightly) shift; exec ${rustNightly}/bin/cargo "\$@" ;;
      +*)              exec ${pkgs.rustup}/bin/cargo "\$@" ;;
      *)               exec ${rustDefault}/bin/cargo "\$@" ;;
    esac
    SHIM

    cat > $out/bin/rustc <<SHIM
    #!${pkgs.runtimeShell}
    if [ -n "\''${RUSTUP_TOOLCHAIN:-}" ]; then
      exec ${pkgs.rustup}/bin/rustc "\$@"
    else
      exec ${rustDefault}/bin/rustc "\$@"
    fi
    SHIM

    chmod +x $out/bin/cargo $out/bin/rustc
  '';

  # The SBF LLVM + rust toolchain. cargo-build-sbf would fetch and
  # self-patchelf this at build time; install_if_missing() skips both when
  # its target is a symlink, which the tmpfiles rule below provides.
  platformTools = pkgs.stdenv.mkDerivation rec {
    pname = "solana-platform-tools";
    version = "v1.52";                 # what anchor 1.0.2 asks for

    src = pkgs.fetchurl {
      url = "https://github.com/anza-xyz/platform-tools/releases/download/${version}/platform-tools-linux-x86_64.tar.bz2";
      hash = "sha256-izhh6T2vCF7BK2XE+sN02b7EWHo94Whx2msIqwwdkH4=";
    };

    sourceRoot = ".";                  # tarball has no top-level dir

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
      pkgs.libedit
      pkgs.ncurses
      pkgs.xz
      pkgs.libxml2
    ];

    # Both only affect lldb, which nothing here uses.
    autoPatchelfIgnoreMissingDeps = [ "libpython3.10.so.1.0" ];
    dontCheckForBrokenSymlinks = true;

    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r rust llvm version.md $out/
      runHook postInstall
    '';

    # nixpkgs ships libedit.so.0 and libxml2.so.16; these want .so.2. Must
    # run before autoPatchelf resolves deps.
    preFixup = ''
      while IFS= read -r -d ''' f; do
        if [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" = "7f454c46" ]; then
          patchelf \
            --replace-needed libedit.so.2 libedit.so \
            --replace-needed libxml2.so.2 libxml2.so \
            "$f" 2>/dev/null || true
        fi
      done < <(find $out -type f -print0)
    '';
  };

  # What `anchor build` shells out to. nixpkgs' solana-cli can't ship it:
  # agave's root Cargo.toml excludes platform-tools-sdk/ from the workspace.
  cargoBuildSbf = pkgs.rustPlatform.buildRustPackage rec {
    pname = "solana-cargo-build-sbf";

    # Pinned separately from pkgs.solana-cli so nixpkgs bumps can't move
    # cargoHash or break the postPatch below.
    version = "4.0.3";
    src = pkgs.fetchFromGitHub {
      owner = "anza-xyz";
      repo = "agave";
      tag = "v${version}";
      hash = "sha256-lbkuywAuLeTIoe/5zbKmxCbnNcEx96BiX6ftNJHutZE=";
    };

    sourceRoot = "${src.name}/platform-tools-sdk";
    cargoHash = "sha256-VYNVdO2nMcLvE6AWd1IJpixnZaIQHfKY79+gzekxiK8=";

    buildInputs = [ pkgs.openssl pkgs.bzip2 ];

    # anchor passes --tools-version v1.52 itself; upstream defaults to
    # v1.54, so retarget it or a hand-run build misses the symlink and
    # fetches its own 1.6 GB copy.
    postPatch = ''
      substituteInPlace cargo-build-sbf/src/toolchain.rs \
        --replace-fail 'DEFAULT_PLATFORM_TOOLS_VERSION: &str = "v1.54"' \
                       'DEFAULT_PLATFORM_TOOLS_VERSION: &str = "v1.52"'
    '';

    cargoBuildFlags = [
      "-p" "solana-cargo-build-sbf"
      "-p" "solana-cargo-test-sbf"
    ];

    doCheck = false;                   # suite wants network and a toolchain

    nativeBuildInputs = [ pkgs.pkg-config pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/cargo-build-sbf --prefix PATH : ${rustupShim}/bin
      wrapProgram $out/bin/cargo-test-sbf  --prefix PATH : ${rustupShim}/bin
    '';
  };
in

{
  environment.systemPackages = [
    solanaCli                        # solana, solana-keygen, test-validator
    anchorPinned
    cargoBuildSbf
  ];

  # Where cargo-build-sbf looks for platform-tools. Interpolating the store
  # path also GC-roots it.
  systemd.tmpfiles.rules = [
    "L+ /home/ivsopi3/.cache/solana/${platformTools.version}/platform-tools - - - - ${platformTools}"
  ];
}
