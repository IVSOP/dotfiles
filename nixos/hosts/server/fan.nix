{ config, pkgs, ... }:

let
  eq14Fan = pkgs.writeText "eq14-fan.py" ''
    import os
    from pathlib import Path
    import socket
    import sys
    import time

    # Temperatures are IT8613 temp1 readings in millidegrees Celsius.
    START_TEMP = 55_000
    STOP_TEMP = START_TEMP - 3_000
    RAMP_START_TEMP = 40_000
    FULL_SPEED_TEMP = 90_000
    COOLDOWN_SECONDS = 30
    STARTUP_TIMEOUT_SECONDS = 6
    AUTOMATIC_START_PWM = 60
    PWM_PER_DEGREE = 1

    def read(device, attribute):
        return int((device / attribute).read_text())

    def write(device, attribute, value):
        (device / attribute).write_text(f"{value}\n")

    def find_controller():
        controllers = [
            device.resolve()
            for device in Path("/sys/class/hwmon").glob("hwmon*")
            if (device / "name").read_text().strip() == "it8613"
        ]
        if len(controllers) != 1:
            raise RuntimeError(f"Expected one IT8613 controller, found {len(controllers)}")
        return controllers[0]

    def restore_automatic(device, marker):
        # Manual duty and automatic start PWM share the same IT8613 register.
        write(device, "pwm2_auto_start", AUTOMATIC_START_PWM)
        write(device, "pwm2_enable", 2)
        marker.unlink()

    def run(marker, notify):
        device = find_controller()
        if marker.exists():
            restore_automatic(device, marker)
        if read(device, "pwm2_enable") != 2 or read(device, "pwm2_auto_channels_temp") != 1:
            raise RuntimeError("Expected PWM2 in automatic mode using temp1")

        # Restore the original running curve. A low off register lets the
        # software hold the fan on while the board sensor cools.
        for attribute, value in (
            ("pwm2_auto_point1_temp", 0),
            ("pwm2_auto_point2_temp", RAMP_START_TEMP),
            ("pwm2_auto_start", AUTOMATIC_START_PWM),
            ("pwm2_auto_slope", PWM_PER_DEGREE * 8),  # Encoded in eighths.
            ("pwm2_auto_point1_temp_hyst", -4000),  # Keep the original 4°C offset.
            ("pwm2_auto_point3_temp", FULL_SPEED_TEMP),
        ):
            write(device, attribute, value)

        notify.sendall(b"READY=1")
        cool_since = None
        startup_since = None
        fan_off = False
        while True:
            temperature = read(device, "temp1_input")
            now = time.monotonic()
            if fan_off:
                if temperature >= START_TEMP or startup_since is not None:
                    startup_finished = startup_since is not None and (
                        now - startup_since >= STARTUP_TIMEOUT_SECONDS
                        or read(device, "fan2_input") > 0
                    )
                    if temperature >= FULL_SPEED_TEMP or startup_finished:
                        restore_automatic(device, marker)
                        fan_off = False
                        startup_since = None
                    else:
                        # Get the fan turning at the original curve's duty before handing it back.
                        rise = max(0, temperature - RAMP_START_TEMP)
                        write(device, "pwm2", AUTOMATIC_START_PWM + rise * PWM_PER_DEGREE // 1000)
                        if startup_since is None:
                            startup_since = now
            elif temperature > STOP_TEMP:
                cool_since = None
            elif cool_since is None:
                cool_since = now
            elif now - cool_since >= COOLDOWN_SECONDS:
                marker.touch()
                write(device, "pwm2_enable", 1)
                write(device, "pwm2", 0)
                fan_off = True
                cool_since = None

            notify.sendall(b"WATCHDOG=1")
            time.sleep(2)

    marker = Path(os.environ["RUNTIME_DIRECTORY"]) / "manual-pwm-device"
    if sys.argv[1:] == ["restore"]:
        if marker.exists():
            restore_automatic(find_controller(), marker)
    else:
        address = os.environ["NOTIFY_SOCKET"]
        if address.startswith("@"):
            address = "\0" + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as notify:
            notify.connect(address)
            run(marker, notify)
  '';
in
{
  # The EQ14's IT8613E needs the extended it87 driver. Install under updates
  # so depmod prefers it over the kernel's bundled it87 module.
  boot.extraModulePackages = [
    (config.boot.kernelPackages.it87.overrideAttrs (old: {
      makeFlags = old.makeFlags ++ [
        "MODDESTDIR=$(out)/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/updates"
      ];
    }))
  ];
  boot.kernelModules = [ "it87" ];

  # The service handles fan stop and startup. The IT8613 sets the running speed.
  systemd.services.eq14-fan-curve = {
    description = "Manage EQ14 fan stop and automatic cooling";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "notify";
      ExecStart = "${pkgs.python3}/bin/python3 ${eq14Fan}";
      ExecStopPost = "${pkgs.python3}/bin/python3 ${eq14Fan} restore";
      RuntimeDirectory = "eq14-fan-curve";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "restart";
      WatchdogSec = "10s";
      WatchdogSignal = "SIGKILL";
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };
}
