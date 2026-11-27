{ lib, pkgs, ... }:

let
  port = 53317;
  release = {
    x86_64-linux = {
      arch = "x86-64";
      hash = "sha256-NOuRtjytxJRhkIGCfQBaYEhAGUWg+lQYRr6hKBkv9bw=";
    };
    aarch64-linux = {
      arch = "arm-64";
      hash = "sha256-jpIj0uhHE7xgkXqEWfEVesSO4905JOvthuPccbBHKVc=";
    };
  }.${pkgs.stdenv.hostPlatform.system};

  localsend-cli = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "localsend-cli";
    version = "1.19.0";

    # Upstream's static Linux builds need no dynamic linker patching on NixOS.
    src = pkgs.fetchurl {
      url = "https://github.com/localsend/localsend/releases/download/v${finalAttrs.version}/LocalSend-CLI-${finalAttrs.version}-linux-${release.arch}-musl.tar.gz";
      inherit (release) hash;
    };
    sourceRoot = ".";
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      install -Dm755 localsend-cli "$out/bin/localsend-cli"
      runHook postInstall
    '';

    meta = {
      description = "Terminal client for sending files between nearby devices";
      homepage = "https://localsend.org";
      license = lib.licenses.asl20;
      mainProgram = "localsend-cli";
      platforms = [ "x86_64-linux" "aarch64-linux" ];
    };
  });
in
{
  environment.systemPackages = [ localsend-cli ];

  # UDP is used for multicast discovery and TCP is used for transfers.
  networking.firewall.allowedTCPPorts = [ port ];
  networking.firewall.allowedUDPPorts = [ port ];
}
