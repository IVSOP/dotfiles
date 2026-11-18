{ nixpkgs-hyprland, hy3, ... }:

{
  hy3Overlay = final: prev: let
    hyprlandPkgs = nixpkgs-hyprland.legacyPackages.${final.stdenv.hostPlatform.system};
  in {
    inherit (hyprlandPkgs) hyprland xdg-desktop-portal-hyprland;
    hy3 = hyprlandPkgs.callPackage "${hy3}/default.nix" {
      inherit (hyprlandPkgs) hyprland;
      hlversion = hyprlandPkgs.hyprland.version;
    };
  };
}
