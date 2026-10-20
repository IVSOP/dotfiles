# Shared shell, CLI tools, and system defaults for the desktop, laptop, and server.
{ lib, pkgs, ... }:

{
  # Apply to all LUKS mappings, including those in generated hardware configs.
  # Discards expose unused block locations; devices can opt out with false.
  imports = [
    {
      options.boot.initrd.luks.devices = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          config.allowDiscards = lib.mkDefault true;
        });
      };
    }
  ];

  services.fstrim = {
    enable = lib.mkDefault true;
    interval = lib.mkDefault "weekly";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # ── System tuning ────────────────────────────────────────────────────
  boot.tmp.useTmpfs = true;
  boot.kernel.sysctl."vm.swappiness" = 1;
  services.journald.settings.Journal.SystemMaxUse = "100M";

  # ── Time / Locale ────────────────────────────────────────────────────
  time.timeZone = "Europe/Lisbon";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Nix settings ─────────────────────────────────────────────────────
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ssh-agent as a systemd user service, socket at $XDG_RUNTIME_DIR/ssh-agent.
  # Replaces the hand-rolled ssh-agent block that used to live in .zshrc:
  # this starts before the session, so graphical launches (hyprland keybinds,
  # .desktop entries) get SSH_AUTH_SOCK too, not just interactive shells.
  programs.ssh.startAgent = true;
  programs.ssh.agentTimeout = "3h";

  # ── Shell ─────────────────────────────────────────────────────────────
  programs.zsh.enable = true;

  environment.variables.EDITOR = "nvim";

  # CLI tools used by the shell, shared by all x86 hosts.
  environment.systemPackages = with pkgs; [
    # ─ CLI essentials ─
    neovim
    delta
    tmux
    wget
    curl
    unzip
    zip
    file
    tree
    man-pages
    usbutils         # lsusb
    pciutils         # lspci

    # ─ CLI tools ─
    eza
    bat
    fzf
    ripgrep
    fd
    jq
    pv
    zstd
    age
    gum
    chafa
    rsync
    psmisc
    gdu
    duf
    nethogs
    lazygit
    lazydocker
    claude-code
    codex
    yazi
    fend
    tldr
    gnupg
    sshfs
    netcat-openbsd
    w3m
  ];

  # ── Git ──────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user = {
        name = "Ivan Ribeiro";
        email = "ivan.ribeiro09s@gmail.com";
      };
      core = {
        editor = "code --wait";
        pager = "bat";
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        dark = true;
      };
      merge.conflictstyle = "zdiff3";
      init.defaultBranch = "master";
      credential.helper = "cache";
      alias = {
        lg = "lg4";
        lg1 = "lg1-specific --all";
        lg2 = "lg2-specific --all";
        lg3 = "lg3-specific --all";
        lg4 = "log --graph --oneline --decorate --all";
        grhh = "reset --hard";
        nuke = "!git reset --hard && git clean -fdx";
        history = "!git log --color=always --oneline | fzf --reverse --multi --ansi --preview 'git show --color=always {+1}'";
        rank = "!git shortlog -n -s --no-merges | nl | grep --color -z -E 'Ivan Ribeiro|IVSOP'";
        review = "!git diff --name-only | fzf -m --ansi --preview 'git diff --color=always -- {-1}'";
        lg1-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(auto)%d%C(reset)'";
        lg2-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
        lg3-specific = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset) %C(bold cyan)(committed: %cD)%C(reset) %C(auto)%d%C(reset)%n''          %C(white)%s%C(reset)%n''          %C(dim white)- %an <%ae> %C(reset) %C(dim white)(committer: %cn <%ce>)%C(reset)'";
      };
    };
  };

  # FHS shebang paths. NixOS ships only /bin/sh and /usr/bin/env, so scripts
  # written on Arch (where /bin is a symlink to /usr/bin) need the path they
  # actually name. Prefer `#!/usr/bin/env bash` in new scripts over growing
  # this list.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /usr/bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
  ];
}
