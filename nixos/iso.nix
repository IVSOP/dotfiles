{ config, pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix>
  ];

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
