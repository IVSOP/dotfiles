# Solana CLI, Anchor, and the SBF tools are pinned independently of general Rust.
{ pkgs, nixpkgs-anchor, nixpkgs-solana, rustDefault, rustNightly, ... }:

let
  pins = import ./pins.nix;
  solanaPkgs = import nixpkgs-solana { inherit (pkgs.stdenv.hostPlatform) system; };
  anchorPackage = (import nixpkgs-anchor { inherit (pkgs.stdenv.hostPlatform) system; }).anchor;

  # 1.0.2, from the last nixpkgs that packaged it; this system's nixpkgs
  # ships 1.1.2. Imported bare, without the system's overlays.
  anchorPinned = assert anchorPackage.version == pins.anchor.version; pkgs.symlinkJoin {
    name = "anchor-${pins.anchor.version}";
    paths = [ anchorPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/anchor --prefix PATH : ${anchorCargoShim}/bin:${rustupShim}/bin
    '';
  };

  # Anchor 1.0.2 hardcodes v1.52. Redirect only its build invocation to
  # our pinned tools; direct cargo-build-sbf calls keep their CLI overrides.
  anchorCargoShim = pkgs.writeShellScriptBin "cargo" ''
    if [ "$1" = "build-sbf" ] && [ "$2" = "--tools-version" ] && [ "$3" = "v1.52" ]; then
      shift 3
      exec ${rustupShim}/bin/cargo build-sbf --tools-version ${platformTools.version} "$@"
    fi
    exec ${rustupShim}/bin/cargo "$@"
  '';

  # Temporary workaround: nixpkgs' cargoSetupHook now requires system libraries
  # that solana-cli 4.0.3 omits. After future nixpkgs/Solana updates, try removing
  # this override and rebuilding; keep just `solanaCli = solanaPkgs.solana-cli;` once
  # it builds successfully without the workaround.
  solanaCli = assert solanaPkgs.solana-cli.version == pins.solanaCli.version; solanaPkgs.solana-cli.overrideAttrs (old: {
    buildInputs = (old.buildInputs or [ ]) ++ [
      solanaPkgs.zstd
      solanaPkgs.zlib
      # Agave enables unprefixed_malloc_on_supported_platforms. This helper
      # supplies a matching allocator and sets JEMALLOC_OVERRIDE for Cargo.
      solanaPkgs.rust-jemalloc-sys-unprefixed
    ];
  });

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
    version = pins.solanaPlatformTools.version; # Rust 1.95.0 / LLVM 22

    src = pkgs.fetchurl {
      url = "https://github.com/anza-xyz/platform-tools/releases/download/${version}/platform-tools-linux-x86_64.tar.bz2";
      hash = "sha256-e4LrQgta69HlWQ2wriXFI+ygZyTUI4rgITlpBTVjbDc=";
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

  # What `anchor build` shells out to, pinned independently of solana-cli.
  # Upstream now releases the builder from its own repository.
  cargoBuildSbf = pkgs.rustPlatform.buildRustPackage rec {
    pname = "solana-cargo-build-sbf";

    # Pinned separately from pkgs.solana-cli so nixpkgs bumps can't move
    # cargoHash or break the postPatch below.
    version = pins.cargoBuildSbf.version;
    src = pkgs.fetchFromGitHub {
      owner = "anza-xyz";
      repo = "cargo-build-sbf";
      tag = "cargo-build-sbf@v${version}";
      hash = "sha256-67ZdFbKFqZHU2odJoyZ2GLBL7F4QVcNhg6DjYZIEV2s=";
    };

    cargoHash = "sha256-2KsSpuxc4/1+8e4Wu4T+Pzd3wK/22Dus7kYDSkiZ0MQ=";

    buildInputs = [ pkgs.openssl pkgs.bzip2 ];

    # Match the Nix-provided tools so direct builds do not fetch another copy.
    # Preserve the existing v0 target; migrating programs to SBPFv3 is separate.
    postPatch = ''
      substituteInPlace cargo-build-sbf/src/toolchain.rs \
        --replace-fail 'DEFAULT_PLATFORM_TOOLS_VERSION: &str = "v1.57"' \
                       'DEFAULT_PLATFORM_TOOLS_VERSION: &str = "${platformTools.version}"'
      substituteInPlace cargo-build-sbf/src/bin/{build_sbf,test_sbf}.rs \
        --replace-fail '.default_value("v3")' '.default_value("v0")'
    '';

    cargoBuildFlags = [
      "-p" "cargo-build-sbf"
    ];

    passthru = { inherit platformTools; };

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
  # path also GC-roots it. Explicit parents keep the cache writable by the user.
  systemd.tmpfiles.rules = [
    "d /home/ivsopi3/.cache/solana 0755 ivsopi3 users - -"
    "d /home/ivsopi3/.cache/solana/${platformTools.version} 0755 ivsopi3 users - -"
    "L+ /home/ivsopi3/.cache/solana/${platformTools.version}/platform-tools - ivsopi3 users - ${platformTools}"
  ];
}
