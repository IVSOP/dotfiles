{ inputs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      codex = inputs.nixpkgs-codex.legacyPackages.${final.stdenv.hostPlatform.system}.codex;
    })
  ];
}
