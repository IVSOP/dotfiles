{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    dnsutils # dig, nslookup, host, nsupdate
    doggo    # Modern DNS client with DoH and DoT support
  ];
}
