{ lib, pkgs, ... }:
let
  user = "ivsopi3";
  home = "/home/${user}";
  settings = "${home}/Documents/Vault/.obsidian";
  plugins = {
    obsidian-excalidraw-plugin = {
      repo = "zsviczian/obsidian-excalidraw-plugin";
      version = "2.22.0";
      enable = true;
      hashes = {
        "main.js" = "sha256-j31dxTgigCCAWiVduWFbov24KpwOYIHxs37nwnUKs34=";
        "manifest.json" = "sha256-5HiL0AyYkPYsk51RZ27S6qOSdIpzjyktR3Id9v4QBVM=";
        "styles.css" = "sha256-VYGvZ9mozBM3dEIMeXTQOny8tevOIJ1ujgpT4AvePwA=";
      };
    };
    file-tree-alternative = {
      repo = "ozntel/file-tree-alternative";
      version = "2.6.0";
      enable = false;
      hashes = {
        "main.js" = "sha256-vnY+ZH7iAiaul61OxGez3AN5oZ2xPQNg3zqxrBCafE8=";
        "manifest.json" = "sha256-BOZZiDBOWSEiLE5BMbqkHM5eQrjUlBCrpKpC5NvhWxk=";
        "styles.css" = "sha256-otCr8aeB9uMxK+hpBOpeh9h3SG/aXxidB1uD/bHl1wI=";
      };
    };
    obsidian-git = {
      repo = "Vinzent03/obsidian-git";
      version = "2.41.1";
      enable = false;
      hashes = {
        "main.js" = "sha256-KKGK/KsdLxUqDTyJr/OOKpetC+GuqvmWMGEyM7vsbBs=";
        "manifest.json" = "sha256-XU0PQRUYY2wdKkgxQlqONIe5JbW9QTvgyiLm3jilk/c=";
        "styles.css" = "sha256-v6j71F/kn/NA/bGWuEut1jGu3l1vlnQPM26nec1EEAU=";
      };
    };
    obsidian-livesync = {
      repo = "vrtmrz/obsidian-livesync";
      version = "0.25.56";
      enable = true;
      hashes = {
        "main.js" = "sha256-cuvvN24GCMC/V2w292TrGkypPlzcrzcDUeJc7e1cvRM=";
        "manifest.json" = "sha256-PE6kuSkKJIYUsoEbhu4ENC6WumruT7Hp1Pf9BdKJx0c=";
        "styles.css" = "sha256-SKokAKsGwX0YAoczW+1++6ukiOc9QAi8NB8LJsrox8E=";
      };
    };
  };
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
