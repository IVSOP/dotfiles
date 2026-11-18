# Docker detects pass before secretservice. Expose only the selected helper
# without putting the full helpers package (which contains both) on PATH.
{ backend }:
{ lib, pkgs, ... }:
assert builtins.elem backend [ "secretservice" "pass" ];
{
  environment.systemPackages = [
    (pkgs.runCommand "docker-credential-${backend}" { } ''
      mkdir -p "$out/bin"
      ln -s ${pkgs.docker-credential-helpers}/bin/docker-credential-${backend} "$out/bin/"
    '')
  ] ++ lib.optional (backend == "pass") pkgs.pass
    ++ lib.optional (backend == "secretservice") pkgs.seahorse;

  # The keyring module enables login PAM integration; Ly includes that stack.
  services.gnome.gnome-keyring.enable = backend == "secretservice";
  # The x86 base profile provides the OpenSSH agent.
  services.gnome.gcr-ssh-agent.enable = false;

  programs.gnupg.agent = lib.mkIf (backend == "pass") {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
  };
}
