{ lib, pkgs, ... }:
let
  user = "ivsopi3";
  home = "/home/${user}";
  settings = "${home}/Documents/Vault/.obsidian";
  plugins = (builtins.fromJSON (builtins.readFile ./sources.json)).obsidianPlugins;
  enabled = lib.attrNames (lib.filterAttrs (_: plugin: plugin.enable) plugins);
  dir = path: "d ${path} 0700 ${user} users - -";

  # Non-sensitive defaults from IVPC. Empty objects use Obsidian's defaults.
  # Each file is created only when missing; GUI edits survive rebuilds.
  defaults = {
    "app.json" = { };
    "appearance.json" = { theme = "obsidian"; };
    "hotkeys.json" = { };
    "community-plugins.json" = enabled;
    "core-plugins.json" = {
      file-explorer = true;
      global-search = true;
      switcher = true;
      graph = true;
      backlink = true;
      canvas = true;
      outgoing-link = true;
      tag-pane = true;
      footnotes = false;
      properties = true;
      page-preview = true;
      daily-notes = true;
      templates = true;
      note-composer = true;
      command-palette = true;
      slash-command = false;
      editor-status = true;
      bookmarks = true;
      markdown-importer = false;
      zk-prefixer = false;
      random-note = false;
      outline = true;
      word-count = true;
      slides = false;
      audio-recorder = false;
      workspaces = false;
      file-recovery = true;
      publish = false;
      sync = true;
      bases = true;
      webviewer = false;
    };
  };
in
{
  systemd.tmpfiles.rules = [
    "d ${home}/.config 0755 ${user} users - -"
    "d ${home}/Documents 0755 ${user} users - -"
    "d ${home}/Documents/Vault 0755 ${user} users - -"
    (dir settings)
    (dir "${settings}/plugins")
  ] ++ lib.mapAttrsToList (name: value:
    "f ${settings}/${name} 0600 ${user} users - ${builtins.toJSON value}"
  ) defaults
  ++ lib.concatLists (lib.mapAttrsToList (id: plugin:
    [ (dir "${settings}/plugins/${id}") ]
    ++ lib.mapAttrsToList (name: hash:
      let
        source = pkgs.fetchurl {
          url = "https://github.com/${plugin.repo}/releases/download/${plugin.version}/${name}";
          inherit hash;
        };
      in "L+ ${settings}/plugins/${id}/${name} - ${user} users - ${source}"
    ) plugin.hashes
  ) plugins);
}
