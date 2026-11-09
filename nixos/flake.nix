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
    # Keep Hyprland and its portal on the same package set without updating
    # the rest of the system. hy3 must build against that exact Hyprland.
    nixpkgs-hyprland.url = "github:NixOS/nixpkgs/nixos-unstable";
    hy3 = {
      url = "github:IVSOP/hy3/indicator-0.57";
      flake = false;
    };
    waybar = {
      url = "github:Alexays/Waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nixpkgs-hyprland, nixpkgs-anchor, lanzaboote, nix4vscode, hy3, waybar, rust-overlay, ... }: let
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

    serverSource = builtins.path {
      path = ./.;
      name = "rock-server-configuration";
      filter = path: type: builtins.baseNameOf path != ".git";
    };
    rock4Config = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit serverSource; };
      modules = [ ./radxa/server-image.nix ];
    };
    rock4ConfigForX86Build = rock4Config.extendModules {
      modules = [
        ({ lib, pkgs, ... }: {
          boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor
            nixpkgs.legacyPackages.${system}.pkgsCross.aarch64-multiplatform.linux);
        })
      ];
    };

    hy3Overlay = final: prev: let
      hyprlandPkgs = nixpkgs-hyprland.legacyPackages.${final.stdenv.hostPlatform.system};
    in {
      inherit (hyprlandPkgs) hyprland xdg-desktop-portal-hyprland;
      hy3 = hyprlandPkgs.callPackage "${hy3}/default.nix" {
        inherit (hyprlandPkgs) hyprland;
        hlversion = hyprlandPkgs.hyprland.version;
      };
    };

    waybarOverlay = nixpkgs.lib.composeManyExtensions [
      waybar.overlays.default
      (final: prev: {
        waybar = prev.waybar.overrideAttrs (old: {
          # Temporary: the thread stress test's 5-second watchdog can expire
          # during a busy system build. Match upstream's proposed 60-second
          # budget while keeping the tests enabled.
          # After future Waybar updates, try removing this override and using
          # waybar.overlays.default directly again once its tests pass reliably.
          # Upstream: https://github.com/Alexays/Waybar/pull/5432
          postPatch = (old.postPatch or "") + ''
            substituteInPlace test/utils/sleeper_thread.cpp \
              --replace-fail 'alarm(5);' 'alarm(60);'
          '';
          # Let the suite outlive the subprocess watchdog (Meson defaults to 30s).
          mesonCheckFlags = (old.mesonCheckFlags or [ ]) ++ [ "--timeout-multiplier" "3" ];
        });
      })
    ];

  in {
    nixosConfigurations.rock-server = rock4Config;
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-anchor; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default rust-overlay.overlays.default ]; }
        pinRegistry
        ./server.nix
        ./server-hardware-configuration.nix
      ];
    };
    packages.aarch64-linux.server = rock4Config.config.system.build.toplevel;
    packages.aarch64-linux.server-image = rock4Config.config.system.build.sdImage;
    # x86 builders can select the image too, using ARM binfmt or a remote builder.
    nixosConfigurations.ivX13 = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-anchor; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybarOverlay rust-overlay.overlays.default ]; }
        pinRegistry
        ./dotfiles.nix
        ./configuration.nix
        ./laptop.nix
      ];
    };

    nixosConfigurations.IVPC = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit nixpkgs-anchor; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybarOverlay rust-overlay.overlays.default ]; }
        pinRegistry
        ./dotfiles.nix
        ./configuration.nix
        ./desktop.nix
      ];
    };

    packages.${system} = {
      server-image = rock4ConfigForX86Build.config.system.build.sdImage;
      iso = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./iso.nix ];
      }).config.system.build.isoImage;
    };
  };
}
