# Manual pins. Package definitions and the update reminder read these values.
# Fixed flake input commits are declared in flake.nix and recorded in flake.lock.
{
  anchor.version = "1.0.2";
  solanaCli.version = "4.0.3";
  tracy = {
    attribute = "tracy_0_13";
    version = "0.13.1";
  };
  solanaPlatformTools.version = "v1.58";
  cargoBuildSbf.version = "4.5.0";
}
