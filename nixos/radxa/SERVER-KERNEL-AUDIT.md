# ROCK 4C+ kernel audit

Audited on 2026-10-03. System defaults were ported into `radxa-defaults.nix`
before inspecting the kernel. `schedutil` remains selected.

## What the official build selects

RSDK installs `linux-image-rock-4c-plus`. In BSP revision
`8296ccd2a51e7ad7f41529b1045f8bfd1392dba3`, the active `linux/rockchip`
profile creates that metapackage and selects:

```text
source:    https://github.com/radxa/kernel.git
branch:    linux-5.10-gen-rkr3.4
defconfig: rockchip_linux_defconfig
```

The branch checked out for this audit is
`8977aaaf5cad6497f157f31d4ccf2149ee784cca`. Its Makefile identifies Linux
**5.10.110**. Radxa's repository source-package index lists `linux-rockchip`
as `5.10.110-39`; this does not identify the kernel installed on your existing
SD card. An individual image release may pin an older package/source revision.
Check `uname -r` and its release fingerprint for that information.

The hidden `.rk3399t` profile pointing at Linux 4.4 is an older alternative;
it is not the active profile above. RSDK's separate common-kernel-config patch
is also not the BSP profile's configuration entry point.

Sources: [RSDK package selection](https://github.com/RadxaOS-SDK/rsdk/blob/54a73ca7a8ce13823456bae162fe7d5d277ab1c2/src/share/rsdk/build/mod/packages/categories/core.libjsonnet),
[BSP profile](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/linux/rockchip/fork.conf),
[metapackage generation](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/lib/linux.sh),
[source version](https://github.com/radxa/kernel/blob/8977aaaf5cad6497f157f31d4ccf2149ee784cca/Makefile),
[repository index](https://radxa-repo.github.io/rk3399t-bookworm/pkgs.json).

## Why a vendor fork

The source and configuration show concrete dependencies on Rockchip's hardware
stack. This is an explanation inferred from those dependencies, rather than a
published statement of Radxa's entire decision process:

* The fork contains Rockchip MPP video drivers, vendor camera/ISP drivers,
  Mali GPU drivers, and display plumbing. The official image's vendor packages
  include matching MPP, camera, GStreamer, Chromium, DRM, and Xorg components.
  Moving just the kernel can break those kernel/userspace interfaces.
* The board's second micro-HDMI path is wired through DisplayPort conversion.
  The vendor tree enables it using `linux,extcon-pd-virtual`, `cdn_dp`, and
  `tcphy0_dp`. This needs more support than the ordinary HDMI controller.
* The BSP configuration documents driver initialization constraints: some camera,
  storage, USB, and display components must be built in to initialize correctly.
  It also explicitly enables `CONFIG_DRM_IGNORE_IOTCL_PERMIT` to work around
  MPP access and an RK3399 Xorg "screen not found" failure. That relaxation is
  specific to the vendor graphics stack and has not been copied into NixOS.
* Maintaining the same vendor interfaces across the board family avoids having
  to port every multimedia package whenever upstream changes its interfaces.
  The older kernel version alone does not tell us whether a particular driver
  works better, or which later security fixes Radxa has backported.

Sources: [vendor defconfig](https://github.com/radxa/kernel/blob/8977aaaf5cad6497f157f31d4ccf2149ee784cca/arch/arm64/configs/rockchip_linux_defconfig),
[MPP driver tree](https://github.com/radxa/kernel/tree/8977aaaf5cad6497f157f31d4ccf2149ee784cca/drivers/video/rockchip/mpp),
[documented workarounds](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/linux/.rockchip/kconfig.conf),
[vendor board device tree](https://github.com/radxa/kernel/blob/8977aaaf5cad6497f157f31d4ccf2149ee784cca/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dts).

## Precisely what BSP adds to that fork

The fork already contains extensive Rockchip changes. BSP then runs custom source
actions, applies patches in sorted directory order, loads the defconfig, merges
the shared and profile configuration fragments, and runs `olddefconfig`.
Its `.common` source action copies Radxa overlays from revision
`552501587a4d2d1b79493c690c6af01f73407ee5` into the kernel device-tree directory.

The active profile has **12 applied patch files**:

| Patch under `linux/rockchip` | Change |
| --- | --- |
| `0010-backport/0003` | Fix GCC 12 array-comparison build failure in page allocator. |
| `0010-backport/0004` | Adjust Ethernet address function declarations for GCC warnings. |
| `0100-vendor/0001` | Build/install Radxa overlays and scripts; emit device-tree symbols, including for ROCK 4C+. |
| `0100-vendor/0002` | Suppress compiler warnings affecting the older vendor source. |
| `0100-vendor/0003` | Make selected Rockchip flash options built-in-only. |
| `0100-vendor/0004` | Make Rockchip suspend and FIQ debugger built-in-only because symbols are not exported. |
| `0100-vendor/0005` | Make CEC core built-in-only to satisfy vendor dependencies. |
| `0100-vendor/0006` | Revert vendor/GKI modularization of DMA-buf software synchronization. |
| `0100-vendor/0007` | Make Rockchip GPIO and pinctrl built-in-only, since boot needs them. |
| `0100-vendor/0009` | Add GPU compatible strings so Panfrost can detect RK3399. |
| `0100-vendor/0010` | Give Debian libc-header packages versioned names. |
| `0100-vendor/0012` | Add the separate ROCK 4 Core IO board's device trees. |

The two `0200-vendor-staging/*.patch.ignore` files are not applied. Shared
configuration enables container networking/cgroups, zram, wireless drivers,
additional peripherals, CPU governors, thermal governors, and overlays. The
profile also disables several bundled Realtek drivers in favor of DKMS packages.
These lists describe the BSP layer exactly; they are not a complete diff of the
underlying vendor fork against vanilla Linux 5.10.110.

Sources: [build ordering](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/lib/utils.sh),
[patch directories](https://github.com/radxa-repo/bsp/tree/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/linux/rockchip),
[shared config](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/linux/.common/kconfig.conf),
[overlay source action](https://github.com/radxa-repo/bsp/blob/8296ccd2a51e7ad7f41529b1045f8bfd1392dba3/linux/.common/overlays.sh).

## What this means for our NixOS configuration

At the existing nixpkgs lock, `pkgs.linuxPackages` selects **6.18.54**. Comparing
its ROCK 4C+ device tree and includes with the vendor tree gives:

| Feature | Upstream 6.18.54 source |
| --- | --- |
| CPU frequency/voltage limits | Dedicated RK3399-T table: LITTLE up to 1.008 GHz, big up to 1.512 GHz; matches the vendor CPU table. |
| Ethernet | Enabled GMAC and PHY setup; no r8125 driver needed for onboard GMAC. |
| microSD/eMMC | Board-specific MMC controllers and power supplies are described. |
| USB host | USB2/USB3 controllers, PHYs, and host power supplies are enabled. |
| Wi-Fi/Bluetooth | Broadcom SDIO and UART nodes are present; our small firmware package supplies their firmware. |
| Serial console | Standard UART2 / `ttyS2` at 1500000 baud; vendor uses its FIQ debugger / `ttyFIQ0`. |
| GPIO | Standard Rockchip GPIO support; our existing patch explicitly enables character-device API v1 for `gpio-cdev` 0.6. |
| Thermal protection | TSADC enabled with upstream thermal definitions; vendor temperature thresholds are not transplanted. |
| HDMI | Ordinary HDMI is enabled; the vendor's second-display virtual-PD path is absent from this board tree. |
| PWM fan | Vendor board tree defines a PWM fan; upstream board tree does not. Your fan connected to 5 V and ground runs directly, independently of this. |
| Camera/video acceleration | Upstream uses different drivers/APIs; equivalent vendor MPP/camera behavior has not been validated. |
| Pin overlays | No overlays selected. Permissions do not enable SPI/I2C/UART pinmux automatically. |

Sources: [upstream board tree](https://github.com/gregkh/linux/blob/v6.18.54/arch/arm64/boot/dts/rockchip/rk3399-rock-4c-plus.dts),
[upstream RK3399-T limits](https://github.com/gregkh/linux/blob/v6.18.54/arch/arm64/boot/dts/rockchip/rk3399-t.dtsi),
[vendor RK3399-T limits](https://github.com/radxa/kernel/blob/8977aaaf5cad6497f157f31d4ccf2149ee784cca/arch/arm64/boot/dts/rockchip/rk3399-t-opp.dtsi),
[upstream SoC definitions](https://github.com/gregkh/linux/blob/v6.18.54/arch/arm64/boot/dts/rockchip/rk3399-base.dtsi).

For the headless Docker/Tailscale/GPIO server, retain the current mainline kernel.
There is no identified vendor-only requirement for those services. This is a
source-based assessment, not evidence that this particular image boots. A
successful image build and a physical board test remain required. If later
work needs the second HDMI, a controllable PWM fan, or vendor video acceleration,
that needs a separate driver/device-tree assessment.

The audit also prompted initrd corrections: include the I2C controller and
RK809/FAN53555 power-regulator drivers when modular; include Rockchip USB2/Type-C PHYs,
DWC3 and its glue, USB storage/UAS, and the eMMC PHY explicitly, alongside the
existing controllers. This keeps modular drivers available before mounting root,
including if the root device is attached through USB. It does not force them
to load if the hardware does not use them.

The system-default ports are independent of that kernel decision: NetworkManager,
Bluetooth, AP6256 firmware, hardware device permissions, LED triggers, zram and
memory tuning, irqbalance policy, time sync, and disabled sleep. Radxa's `ondemand`
tuning is opt-in; no board benchmark established an advantage over `schedutil`.

## Printer, QR reader, and still-image workload

The planned app uses a thermal printer, a QR reader, and still images containing
text, QR codes, and overlays. The peripheral models/interfaces are not yet known;
they will not use GPIO. These requirements do not currently establish a need for
the vendor kernel.

Keep mainline and start with CPU rendering for still images. FFmpeg's `-hwaccel`
selects decoding acceleration; it does not automatically accelerate text drawing
or the complete image composition pipeline. Rockchip RGA can accelerate certain
scaling/blending operations, but `ffmpeg-rockchip` requires a vendor kernel and
matching libraries. Its actual supported operations on RK3399 and the benefit for
this workload would need testing. MPP video acceleration is a separate concern.

Sources: [FFmpeg hardware acceleration options](https://ffmpeg.org/ffmpeg.html#Advanced-Video-options),
[ffmpeg-rockchip requirements and filters](https://github.com/nyanmisaka/ffmpeg-rockchip).

`ivsopi3` has the standard `lp` and `dialout` groups for kernel printer and serial
nodes. No CUPS daemon, printer driver suite, or FFmpeg package is installed yet;
the app is transferred separately. Some thermal printers accept ESC/POS directly.
A model-specific CUPS driver, libusb permissions, or serial settings may be needed.
USB keyboard-style QR readers use the standard HID driver, but a background app
reading raw HID/input events may need a device-specific permission rule.
Do not grant access to every input device just to support one scanner.
Use USB IDs and `/dev/serial/by-id` or a dedicated udev symlink when identifying
hardware for the eventual Compose service.

Containers share the host kernel. Adding Rockchip libraries inside a container
cannot provide missing host MPP/RGA drivers. The eventual Compose configuration
must also pass through the required devices and groups; ordinary USB peripherals
do not require a privileged container.

## Driver coverage for the headless server

No additional vendor-only driver requirement was identified for Ethernet,
storage, USB peripherals, Wi-Fi/Bluetooth, GPIO, or CPU/thermal management.
This is based on upstream device-tree and driver sources, not a physical boot.
The unresolved peripheral details are the printer/scanner models and their
application-level protocol or permissions. USB printer, CDC ACM/USB-serial, and
HID drivers already exist upstream; some printers additionally need userspace
filters or a vendor protocol.

Kernel age is only one part of support. Board-specific device-tree data must
describe clocks, regulators, pins and attached devices; drivers must be enabled
in the chosen kernel build; firmware may be supplied separately. A generic new
kernel does not automatically describe every ARM board or provide a vendor's
MPP/RGA interfaces. USB devices make discovery easier, but may still require
firmware, permissions, or userspace software.

Sources: [Linux device-tree model](https://docs.kernel.org/devicetree/usage-model.html),
[firmware requests](https://docs.kernel.org/driver-api/firmware/request_firmware.html),
[USB printer and ACM drivers](https://github.com/gregkh/linux/blob/v6.18.54/drivers/usb/class/Kconfig).

## Validation performed

* Evaluated the directly bootable server/image derivations, including manual
  local password setup, no autologin, and automatic root partition expansion.
* Evaluated default `schedutil` and explicitly overridden `ondemand`: the tuning
  service exists only in the latter; NetworkManager is enabled and dhcpcd disabled.
* Built the four pinned firmware downloads and their output package on x86;
  all content hashes matched.
* Checked udev rule syntax with temporary known group names; actual device events
  and group permissions need runtime verification on the ROCK.
* No full ARM kernel/image build or physical boot was performed.

Official repositories are kept in `~/clones`; temporary evaluation files and
the portable Nix store are removed after this audit. No system-wide Nix was installed.
