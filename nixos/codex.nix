{ ... }:

{
  # Temporary workaround: cargoSetupHook requires system libraries that
  # Codex 0.167.0 omits. After future nixpkgs/Codex updates, try removing this
  # overlay and rebuilding. Once Codex builds without it, delete this module
  # and its imports from common.nix and iso.nix.
  # Upstream: https://github.com/NixOS/nixpkgs/issues/585124
  nixpkgs.overlays = [
    (final: prev: {
      codex = prev.codex.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [
          final.aws-lc
          final.oniguruma
          final.sqlite
          final.zstd
        ];
      });
    })
  ];
}
