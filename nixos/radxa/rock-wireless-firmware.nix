{ fetchurl, runCommand }:

let
  # Only AP6256 files; avoid installing firmware for unrelated hardware.
  revision = "f19f2c4d5f1349ccffa95adbc28ef59971ed5b56";
  fetchFirmware = name: hash: fetchurl {
    url = "https://raw.githubusercontent.com/radxa-pkg/radxa-firmware/${revision}/radxa-firmware/lib/firmware/brcm/${name}";
    inherit hash;
  };
  wifi = fetchFirmware "brcmfmac43456-sdio.bin" "sha256-eXhyeng9sJ9E3i6HszSK3w+gscb4XuCTVF+U8OV/GA8=";
  clm = fetchFirmware "brcmfmac43456-sdio.clm_blob" "sha256-Lb19Ivya8OtWDOq0WxlkbSEbx7NKHdAMa/rF3WuiXoo=";
  nvram = fetchFirmware "brcmfmac43456-sdio.txt" "sha256-ZscetTtHxJ1COGtmc1E0V4ZAsJRvP0bkTzhP71qs/Z4=";
  bluetooth = fetchFirmware "BCM4345C5.hcd" "sha256-ayQSw+vwo9+tG3Fpz5LHpf3o+rQHs910vBj3Sj77ajo=";
in runCommand "rock-4c-plus-wireless-firmware" { } ''
  mkdir -p "$out/lib/firmware/brcm"
  cp ${wifi} "$out/lib/firmware/brcm/brcmfmac43456-sdio.bin"
  cp ${clm} "$out/lib/firmware/brcm/brcmfmac43456-sdio.clm_blob"
  cp ${nvram} "$out/lib/firmware/brcm/brcmfmac43456-sdio.txt"
  cp ${nvram} "$out/lib/firmware/brcm/brcmfmac43456-sdio.radxa,rock-4c-plus.txt"
  cp ${bluetooth} "$out/lib/firmware/brcm/BCM4345C5.hcd"
''
