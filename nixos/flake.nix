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
  };

  outputs = { nixpkgs, lanzaboote, nix4vscode, ... }: let
    system = "x86_64-linux";
  in {
    nixosConfigurations.ivX13 = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default ]; }
        ./configuration.nix
        ./laptop.nix
      ];
    };

    nixosConfigurations.IVPC = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        lanzaboote.nixosModules.lanzaboote
        { nixpkgs.overlays = [ nix4vscode.overlays.default ]; }
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
