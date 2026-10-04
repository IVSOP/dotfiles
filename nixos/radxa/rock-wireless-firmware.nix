{ fetchurl, runCommand }:

let
  # Small Broadcom firmware set for ROCK 4C+ wireless modules.
  revision = "f19f2c4d5f1349ccffa95adbc28ef59971ed5b56";
  fetchFirmware = directory: name: hash: fetchurl {
    url = "https://raw.githubusercontent.com/radxa-pkg/radxa-firmware/${revision}/radxa-firmware/lib/firmware/${directory}/${name}";
    inherit hash;
  };
  wifi = fetchFirmware "brcm" "brcmfmac43456-sdio.bin" "sha256-eXhyeng9sJ9E3i6HszSK3w+gscb4XuCTVF+U8OV/GA8=";
  clm = fetchFirmware "brcm" "brcmfmac43456-sdio.clm_blob" "sha256-Lb19Ivya8OtWDOq0WxlkbSEbx7NKHdAMa/rF3WuiXoo=";
  nvram = fetchFirmware "brcm" "brcmfmac43456-sdio.txt" "sha256-ZscetTtHxJ1COGtmc1E0V4ZAsJRvP0bkTzhP71qs/Z4=";
  bluetooth = fetchFirmware "brcm" "BCM4345C5.hcd" "sha256-ayQSw+vwo9+tG3Fpz5LHpf3o+rQHs910vBj3Sj77ajo=";
  # BCM4345/6 requests 43455 filenames; Radxa's brcm NVRAM link points here.
  wifi43455 = fetchFirmware "cypress" "cyfmac43455-sdio.bin" "sha256-1QEIeFJuEnNW/T6nrVdUjq6XYkgpnOxhhNt/Kmma4ec=";
  clm43455 = fetchFirmware "cypress" "cyfmac43455-sdio.clm_blob" "sha256-NYzCMVqggebiCeFWf9pR2NFYaI6LgtYUI05Ds/UxyJQ=";
  nvram43455 = fetchFirmware "cypress" "cyfmac43455-sdio.txt" "sha256-LQnjsYCAnvsNGYAE4qX6gPitjooLSkySXf7/izb95Dk=";
  # Fetch the target of BCM4345C0.hcd, rather than its Git symlink text.
  bluetoothC0 = fetchFirmware "brcm" "BCM4345C0_003.001.025.0162.0000_Generic_UART_37_4MHz_wlbga_ref_iLNA_iTR_eLG.hcd" "sha256-R8Pu23R63ffAt+NNuSgaEAZDV5wbofBRAUdPjvCtALg=";
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
