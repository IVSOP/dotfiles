{ lib, pkgs, ... }:

{
  # ── Networking ────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;
  networking.nftables.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────
  services.openssh.enable = true;
  # Defaults to true, which would open 22 on every interface. The firewall
  # section below opens it on tailscale0 only.
  services.openssh.openFirewall = false;
  # Fully manual: `systemctl start sshd`. Not socket-activated — that would
  # still leave systemd listening on 22 from boot.
  systemd.services.sshd.wantedBy = lib.mkForce [ ];
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
  };
  # Drop %h/.ssh/authorized_keys from AuthorizedKeysFile, leaving only
  # /etc/ssh/authorized_keys.d/%u, which nix generates read-only. Keys are
  # then declared in each workstation's host module.
  services.openssh.authorizedKeysInHomedir = false;

  # ── Docker ───────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  # Fully manual: `systemctl start docker`. enableOnBoot drops dockerd from
  # multi-user.target; the socket has to be pulled out of sockets.target too,
  # or the first `docker` command would activate the daemon on demand.
  # docker.service Requires=docker.socket, so starting the service still
  # brings the socket up. `--restart=always` containers only return on start.
  virtualisation.docker.enableOnBoot = false;
  systemd.sockets.docker.wantedBy = lib.mkForce [ ];

  # ── Firewall ─────────────────────────────────────────────────────────
  # NixOS' own firewall (nftables backend), with input dropped by default.
  # LocalSend opens TCP/UDP 53317; SSH is reachable over tailscale0 only.
  # Outbound traffic is never filtered, so there is no "allow out" to write.
  # Temporary holes: `sudo nixos-firewall-tool open tcp 8888` / `... reset`.
  networking.firewall = {
    enable = true;
    checkReversePath = "loose";        # required by tailscale
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ ];
    interfaces."tailscale0".allowedTCPPorts = [ 22 ];
  };

  # ── LocalSend ────────────────────────────────────────────────────────
  programs.localsend = {
    enable = true;
    # Flutter's executable needs libz.so.1 directly. Adding a build input
    # alone does not put zlib in its runtime search path.
    package = pkgs.localsend.overrideAttrs (old: {
      postFixup = (old.postFixup or "") + ''
        ${lib.getExe pkgs.patchelf} --add-rpath ${lib.makeLibraryPath [ pkgs.zlib ]} \
          "$out/app/localsend/localsend_app"
      '';
    });
    openFirewall = false; # The shared LocalSend CLI module opens the same ports.
  };

  # ── Tailscale ────────────────────────────────────────────────────────
  services.tailscale.enable = true;
  # tailscaled ships no socket unit, so this one is genuinely manual:
  # `tup` / `tdown` (systemctl start/stop tailscaled). State is preserved,
  # so it reconnects on start without re-running `tailscale up`.
  systemd.services.tailscaled.wantedBy = lib.mkForce [ ];
  # Opens UDP 41641 so peers can connect directly; without it tailscale still
  # works but every connection is bounced through a DERP relay.
  services.tailscale.openFirewall = true;

  # ── Libvirt / QEMU ──────────────────────────────────────────────────
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
  # Fully manual: `systemctl start libvirtd`. Socket out of sockets.target as
  # well, otherwise virsh/virt-manager would activate the daemon on demand.
  # libvirtd.service Wants its sockets, so starting it brings them up.
  # libvirt-guests (VM autostart/suspend at boot and shutdown) is pointless
  # with no daemon at boot, so it goes too.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];
  systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];
  systemd.sockets.libvirtd.wantedBy = lib.mkForce [ ];
  # virtlogd/virtlockd are the helper daemons' sockets, and unlike the three
  # libvirtd ones they sit in sockets.target, so they were still being opened
  # at boot ("Listening on Virtual machine log/lock manager socket"). They cost
  # nothing and start no daemon, but they are the only libvirt noise left in a
  # boot log. libvirtd.service Requires=virtlogd.socket and Wants=virtlockd.socket,
  # so `systemctl start libvirtd` still pulls both up.
  systemd.sockets.virtlogd.wantedBy = lib.mkForce [ ];
  systemd.sockets.virtlockd.wantedBy = lib.mkForce [ ];
}
