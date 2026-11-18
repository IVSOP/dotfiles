{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Codex releases reach master before nixos-unstable; update this normally.
    nixpkgs-codex.url = "github:NixOS/nixpkgs/master";
    backup-parser = {
      url = "github:IVSOP/backup_parser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    steam-controller-status = {
      url = "github:IVSOP/steam_controller_status";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "rust-overlay";
    };
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
    # Solana CLI 4.0.3, independently pinned from the host toolchain.
    nixpkgs-solana.url = "github:NixOS/nixpkgs/f4a03c008967841f2a0b3cb7c436fc6fc31671f6";
    # Keep Hyprland and its portal on the same package set without updating
    # the rest of the system. hy3 must build against that exact Hyprland.
    nixpkgs-hyprland.url = "github:NixOS/nixpkgs/1d060086d60cb76a40cf37109f979d88a5bd6396";
    hy3 = {
      # Reviewed indicator-0.57 revision, paired with Hyprland 0.57.1.
      url = "github:IVSOP/hy3/a4c8154710a941a683afbd46731503ed92551817";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, nixpkgs-hyprland, ... }: let
    system = "x86_64-linux";

    mkX86System = module: nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [ module ];
    };

    serverSource = builtins.path {
      path = ./.;
      name = "rock-server-configuration";
      filter = path: type: builtins.baseNameOf path != ".git";
    };
    rock4Config = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit serverSource; };
      modules = [ ./images/rock-server.nix ];
    };
    rock4ConfigForX86Build = rock4Config.extendModules {
      modules = [
        ({ lib, pkgs, ... }: {
          boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor
            nixpkgs.legacyPackages.${system}.pkgsCross.aarch64-multiplatform.linux);
        })
      ];
    };

  in {
    lib.manualPins = let
      pins = import ./pins.nix;
      inherit (import ./profiles/workstation/overlays.nix inputs) hy3Overlay;
      fromInput = name: component: version: {
        inherit component;
        inherit version;
        revision = inputs.${name}.rev;
        location = "flake.nix (${name})";
      };
      hyprlandPkgs = nixpkgs-hyprland.legacyPackages.${system};
    in [
      (fromInput "nixpkgs-hyprland" "Hyprland" hyprlandPkgs.hyprland.version)
      {
        component = "Hyprland portal";
        version = hyprlandPkgs.xdg-desktop-portal-hyprland.version;
        revision = nixpkgs-hyprland.rev;
        location = "flake.nix (nixpkgs-hyprland)";
      }
      (fromInput "hy3" "hy3" (hy3Overlay hyprlandPkgs {}).hy3.version)
      (fromInput "nixpkgs-solana" "Solana CLI" pins.solanaCli.version)
      (fromInput "nixpkgs-anchor" "Anchor" pins.anchor.version)
      { component = "Tracy"; version = pins.tracy.version; revision = ""; location = "pins.nix"; }
      { component = "cargo-build-sbf"; version = pins.cargoBuildSbf.version; revision = ""; location = "pins.nix + modules/solana.nix hashes"; }
      { component = "Solana platform-tools"; version = pins.solanaPlatformTools.version; revision = ""; location = "pins.nix + modules/solana.nix hash"; }
    ];

    nixosConfigurations = {
      IVPC = mkX86System ./hosts/IVPC;
      ivX13 = mkX86System ./hosts/ivX13;
      server = mkX86System ./hosts/server;
      rock-server = rock4Config;
    };

    packages.aarch64-linux = {
      server = rock4Config.config.system.build.toplevel;
      server-image = rock4Config.config.system.build.sdImage;
    };

    packages.${system} = {
      # x86 builders can select the image using ARM binfmt or a remote builder.
      server-image = rock4ConfigForX86Build.config.system.build.sdImage;
      iso = (mkX86System ./images/pc-installer.nix).config.system.build.isoImage;
    };
  };
}
