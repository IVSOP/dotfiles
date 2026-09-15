{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix4vscode = {
      url = "github:nix-community/nix4vscode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Last nixpkgs revision that packaged anchor 1.0.2, before the 1.1.2
    # bump in 5f6aeca1d. Used only for that one binary, which the cache
    # already has built; deliberately NOT `follows = "nixpkgs"`, since the
    # whole point is to evaluate it against its own contemporaries.
    nixpkgs-anchor = {
      url = "github:NixOS/nixpkgs/536c906eb9a9a2a38e7a454f4a4ff254b1e6f493";
    };
    hy3 = {
      url = "github:IVSOP/hy3/indicator-0.56";
      flake = false;
    };
    waybar = {
      url = "github:Alexays/Waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-anchor, lanzaboote, nix4vscode, hy3, waybar, rust-overlay, ... }: let
    system = "x86_64-linux";

    # This registry pin is on by default, but without the narHash, so nix reads
    # it as unlocked and skips the eval cache: every `nix search` costs ~75s.
    pinRegistry = {
      nix.registry.nixpkgs.to = {
        type = "path";
        path = nixpkgs.outPath;
        narHash = nixpkgs.narHash;
      };
    };

    hy3Overlay = final: prev: {
      hy3 = final.callPackage "${hy3}/default.nix" {
        inherit (final) hyprland;
	hlversion = final.hyprland.version;
      };
    };

  in {
    nixosConfigurations.ivX13 = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-anchor; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybar.overlays.default rust-overlay.overlays.default ]; }
        pinRegistry
        ./configuration.nix
        ./laptop.nix
      ];
    };

    nixosConfigurations.IVPC = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-anchor; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybar.overlays.default rust-overlay.overlays.default ]; }
        pinRegistry
        ./configuration.nix
        ./desktop.nix
      ];
    };

    packages.${system}.iso = (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ ./iso.nix ];
    }).config.system.build.isoImage;
  };
}
