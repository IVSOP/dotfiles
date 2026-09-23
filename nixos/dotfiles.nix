# Declarative ~/.config and ~ symlinks into the dotfiles repo.
#
# `L+` recreates the link on every rebuild and on boot, deleting whatever is
# at the path first — so only list paths whose real content lives in
# ~/dotfiles. If an app ever replaces one of these with a real file, the next
# rebuild silently throws that file away.
#
# Symlinks (not copies) on purpose: editing ~/.config/hypr/hyprland.conf edits
# the repo, no rebuild needed. Nix only owns the wiring, not the contents.
{ ... }:
let
  user = "ivsopi3";
  home = "/home/${user}";
  dots = "${home}/dotfiles";

  link = target: source: "L+ ${target} - ${user} users - ${source}";
  dir = target: mode: "d ${target} ${mode} ${user} users - -";

  # ~/.config/<n> -> ~/dotfiles/<n>
  configLinks = [
    "alacritty"
    "dunst"
    "electron-flags.conf"
    "flameshot"
    "fontconfig"
    "gtk-2.0"
    "gtk-3.0"
    "gtk-4.0"
    "hypr"
    "mimeapps.list"
    "nemo"
    "nvim"
    "obs-studio"
    "rofi"
    "sway"
    "tmux"
    "waybar"
    "wireplumber"
  ];

  # ~/<n> -> ~/dotfiles/home_dotfiles/<n>
  homeLinks = [
    ".bash_aliases"
    ".bash_funcs"
    ".bash_logout"
    ".bashrc"
    ".nanorc"
    ".nvidia-settings-rc"
    ".profile"
    ".xsessionrc"
    ".zprofile"
    ".zshenv"
    ".zshrc"
  ];

  # Files that live *inside* a directory full of machine-local state, so the
  # directory itself must stay real and only the one config file is linked.
  # Linking ~/.ssh wholesale would take the private keys with it.
  #
  # ~/.codex/config.toml deliberately isn't here: codex rewrites it itself
  # (trust levels, dismissed notices, nux counters), so a link just turns
  # every codex run into a dirty git tree. Settings we actually care about go
  # through the codex wrapper in configuration.nix instead.
  nestedLinks = [
    ".ssh/config"
  ];

  # Anything that doesn't follow the patterns above.
  extraLinks = {
    "${home}/.config/hyprmoncfg" = "${dots}/hypr/monitor-profiles";
  };
in
{
  systemd.tmpfiles.rules =
    # Parents of the nested links, in case the directory doesn't exist yet on
    # a fresh machine. `d` leaves an existing directory and its contents alone.
    [ (dir "${home}/.ssh" "0700") ]
    ++ map (n: link "${home}/.config/${n}" "${dots}/${n}") configLinks
    ++ map (n: link "${home}/${n}" "${dots}/home_dotfiles/${n}") (homeLinks ++ nestedLinks)
    ++ builtins.attrValues (builtins.mapAttrs link extraLinks);
}
