{ fetchurl, runCommand }:

let
  # Small Broadcom firmware set for ROCK 4C+ wireless modules.
  source = (builtins.fromJSON (builtins.readFile ../sources.json)).radxaFirmware;
  inherit (source) revision;
  firmwareHash = directory: name:
    (builtins.head (builtins.filter (file: file.directory == directory && file.name == name) source.files)).hash;
  fetchFirmware = directory: name: hash: fetchurl {
    url = "https://raw.githubusercontent.com/radxa-pkg/radxa-firmware/${revision}/radxa-firmware/lib/firmware/${directory}/${name}";
    inherit hash;
  };
  wifi = fetchFirmware "brcm" "brcmfmac43456-sdio.bin" (firmwareHash "brcm" "brcmfmac43456-sdio.bin");
  clm = fetchFirmware "brcm" "brcmfmac43456-sdio.clm_blob" (firmwareHash "brcm" "brcmfmac43456-sdio.clm_blob");
  nvram = fetchFirmware "brcm" "brcmfmac43456-sdio.txt" (firmwareHash "brcm" "brcmfmac43456-sdio.txt");
  bluetooth = fetchFirmware "brcm" "BCM4345C5.hcd" (firmwareHash "brcm" "BCM4345C5.hcd");
  # BCM4345/6 requests 43455 filenames; Radxa's brcm NVRAM link points here.
  wifi43455 = fetchFirmware "cypress" "cyfmac43455-sdio.bin" (firmwareHash "cypress" "cyfmac43455-sdio.bin");
  clm43455 = fetchFirmware "cypress" "cyfmac43455-sdio.clm_blob" (firmwareHash "cypress" "cyfmac43455-sdio.clm_blob");
  nvram43455 = fetchFirmware "cypress" "cyfmac43455-sdio.txt" (firmwareHash "cypress" "cyfmac43455-sdio.txt");
  # Fetch the target of BCM4345C0.hcd, rather than its Git symlink text.
  bluetoothC0 = fetchFirmware "brcm" "BCM4345C0_003.001.025.0162.0000_Generic_UART_37_4MHz_wlbga_ref_iLNA_iTR_eLG.hcd" (firmwareHash "brcm" "BCM4345C0_003.001.025.0162.0000_Generic_UART_37_4MHz_wlbga_ref_iLNA_iTR_eLG.hcd");
in runCommand "rock-4c-plus-wireless-firmware" { } ''
  mkdir -p "$out/lib/firmware/brcm"
  cp ${wifi} "$out/lib/firmware/brcm/brcmfmac43456-sdio.bin"
  cp ${clm} "$out/lib/firmware/brcm/brcmfmac43456-sdio.clm_blob"
  cp ${nvram} "$out/lib/firmware/brcm/brcmfmac43456-sdio.txt"
  cp ${nvram} "$out/lib/firmware/brcm/brcmfmac43456-sdio.radxa,rock-4c-plus.txt"
  cp ${bluetooth} "$out/lib/firmware/brcm/BCM4345C5.hcd"
  cp ${wifi43455} "$out/lib/firmware/brcm/brcmfmac43455-sdio.bin"
  cp ${clm43455} "$out/lib/firmware/brcm/brcmfmac43455-sdio.clm_blob"
  cp ${nvram43455} "$out/lib/firmware/brcm/brcmfmac43455-sdio.txt"
  cp ${nvram43455} "$out/lib/firmware/brcm/brcmfmac43455-sdio.radxa,rock-4c-plus.txt"
  cp ${bluetoothC0} "$out/lib/firmware/brcm/BCM4345C0.hcd"
''
