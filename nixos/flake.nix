{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    backup-parser = {
      url = "github:IVSOP/backup_parser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Bootvine 0.1.3: update this reviewed commit explicitly.
    bootvine = {
      url = "git+https://codeberg.org/wvhulle/bootvine?rev=a7e33b453a82ecfe9e98d060008b3b20b6924f62";
      inputs.nixpkgs.follows = "nixpkgs";
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
    waybar = {
      url = "github:Alexays/Waybar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ bootvine, nixpkgs, nixpkgs-hyprland, nixpkgs-anchor, nixpkgs-solana, lanzaboote, nix4vscode, hy3, waybar, rust-overlay, ... }: let
    system = "x86_64-linux";

    # Shared by the x86 hosts and installer ISO; keep the Radxa independent.
    bootvineModule = {
      imports = [ bootvine.nixosModules.default ./bootvine.nix ];
    };

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
    lib.manualPins = let
      pins = import ./pins.nix;
      fromInput = name: component: version: {
        inherit component;
        inherit version;
        revision = inputs.${name}.rev;
        location = "flake.nix (${name})";
      };
      hyprlandPkgs = nixpkgs-hyprland.legacyPackages.${system};
    in [
      (fromInput "bootvine" "Bootvine" bootvine.packages.${system}.default.version)
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
      { component = "Codex (official binary)"; version = pins.codex.version; revision = ""; location = "pins.nix (version + archive hash)"; }
      { component = "Tracy"; version = pins.tracy.version; revision = ""; location = "pins.nix"; }
      { component = "cargo-build-sbf"; version = pins.cargoBuildSbf.version; revision = ""; location = "pins.nix + solana.nix hashes"; }
      { component = "Solana platform-tools"; version = pins.solanaPlatformTools.version; revision = ""; location = "pins.nix + solana.nix hash"; }
    ];

    nixosConfigurations.rock-server = rock4Config;
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs nixpkgs-anchor nixpkgs-solana; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default rust-overlay.overlays.default ]; }
        pinRegistry
        bootvineModule
        ./server.nix
        ./server-hardware-configuration.nix
      ];
    };
    packages.aarch64-linux.server = rock4Config.config.system.build.toplevel;
    packages.aarch64-linux.server-image = rock4Config.config.system.build.sdImage;
    # x86 builders can select the image too, using ARM binfmt or a remote builder.
    nixosConfigurations.ivX13 = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs nixpkgs-anchor nixpkgs-solana; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybarOverlay rust-overlay.overlays.default ]; }
        pinRegistry
        bootvineModule
        ./dotfiles.nix
        ./configuration.nix
        ./laptop.nix
      ];
    };

    nixosConfigurations.IVPC = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs nixpkgs-anchor nixpkgs-solana; };
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default hy3Overlay waybarOverlay rust-overlay.overlays.default ]; }
        pinRegistry
        bootvineModule
        ./dotfiles.nix
        ./configuration.nix
        ./desktop.nix
      ];
    };

    packages.${system} = {
      server-image = rock4ConfigForX86Build.config.system.build.sdImage;
      iso = (nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ bootvineModule ./iso.nix ];
      }).config.system.build.isoImage;
    };
  };
}
