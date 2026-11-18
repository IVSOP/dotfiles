{ config, lib, ... }:

{
  config = lib.mkIf config.virtualisation.docker.enable {
    virtualisation.docker.logDriver = "local";
    virtualisation.docker.daemon.settings.log-opts = {
      max-size = "10m";
      max-file = "3";
    };
  };
}
