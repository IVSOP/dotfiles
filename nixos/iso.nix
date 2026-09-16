{ config, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.config.allowUnfree = true;  # claude-code

  environment.systemPackages = with pkgs; [
    # ─ Editor / shell ─
    neovim
    zsh
    tmux

    # ─ Search / nav ─
    ripgrep
    fzf
    fd
    eza
    bat
    tree

    # ─ Git ─
    git

    # ─ AI CLIs ─
    claude-code
    codex

    # ─ Network ─
    curl
    wget
    rsync

    # ─ System info / monitoring ─
    htop
    btop
    smartmontools
    lsof
    pciutils
    usbutils

    # ─ Disk / recovery ─
    testdisk
    ddrescue
    gptfdisk

    # ─ Misc ─
    unzip
    file
    jq
    age
  ];
}
