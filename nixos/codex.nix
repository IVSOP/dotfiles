{ ... }:

let
  pins = import ./pins.nix;
in
{
  # Always install the official prebuilt bundle. A missing download or checksum
  # mismatch must fail, rather than fall back to a memory-intensive Rust build.
  nixpkgs.overlays = [
    (final: prev: {
      codex = final.stdenvNoCC.mkDerivation (finalAttrs: {
        pname = "codex-bin";
        version = pins.codex.version;

        src = final.fetchurl {
          url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
          hash = pins.codex.hash;
        };

        sourceRoot = ".";
        nativeBuildInputs = [ final.installShellFiles ];
        dontConfigure = true;
        dontBuild = true;
        # Preserve the upstream executables and layout for daemon validation.
        dontFixup = true;

        installPhase = ''
          runHook preInstall
          mkdir -p "$out"
          cp -a bin codex-package.json codex-path codex-resources "$out/"
          installShellCompletion --cmd codex \
            --bash <("$out/bin/codex" completion bash) \
            --fish <("$out/bin/codex" completion fish) \
            --zsh <("$out/bin/codex" completion zsh)
          runHook postInstall
        '';

        doInstallCheck = true;
        nativeInstallCheckInputs = [ final.versionCheckHook ];

        meta = {
          description = "Codex CLI, installed from the official binary release";
          homepage = "https://github.com/openai/codex";
          license = final.lib.licenses.asl20;
          mainProgram = "codex";
          platforms = [ "x86_64-linux" ];
        };
      });
    })
  ];
}
