{ pkgs, ... }:

let
  applyCurve = pkgs.writeText "ivpc-fan-curve.py" ''
    from pathlib import Path

    DRIVER = Path("/sys/bus/platform/drivers/nct6775")
    DMI = Path("/sys/class/dmi/id")
    BOARD = "TUF GAMING B850-PLUS WIFI"
    SENSOR = "PECI/TSI Agent 0 Calibration"
    CHANNELS = (1, 2, 3, 4, 6)
    FULL_SPEED = 0
    SMART_FAN_IV = 5

    # Captured from the running NCT6799 with the BIOS Q-Fan curve active.
    # Temperatures are in millidegrees Celsius and duties are out of 255.
    POINTS = (
        (25_000, 51),
        (35_000, 66),
        (45_000, 86),
        (55_000, 114),
        (125_000, 255),  # Critical temperature and duty.
    )

    def read(device, attribute):
        return int((device / attribute).read_text())

    def write(device, attribute, value):
        (device / attribute).write_text(f"{value}\n")

    def find_controller():
        if (DMI / "board_name").read_text().strip() != BOARD:
            raise RuntimeError(f"Expected motherboard {BOARD}")

        controllers = [
            device.resolve()
            for device in DRIVER.glob("nct6775.*/hwmon/hwmon*")
            if (device / "name").read_text().strip() == "nct6799"
        ]
        if len(controllers) != 1:
            raise RuntimeError(f"Expected one NCT6799, found {len(controllers)}")
        return controllers[0]

    def curve_settings(channel, sensor):
        settings = {
            "mode": 1,  # PWM. Set before timings, which depend on the output mode.
            "temp_sel": sensor,
            "step_up_time": 8_000,
            "step_down_time": 8_000,
            "stop_time": 24_000,
            "start": 1,
            "crit_temp_tolerance": 2_000,
        }
        if channel == 2:
            settings["weight_temp_sel"] = 0
        for point, (temperature, duty) in enumerate(POINTS, start=1):
            settings[f"auto_point{point}_temp"] = temperature
            settings[f"auto_point{point}_pwm"] = duty
        # The driver commits this tolerance when Smart Fan IV is enabled.
        settings["temp_tolerance"] = 0
        settings["enable"] = SMART_FAN_IV
        return {f"pwm{channel}_{name}": value for name, value in settings.items()}

    def apply_channel(device, channel, settings):
        enable = f"pwm{channel}_enable"
        # Keep this channel at full speed while its trip points are changing.
        write(device, enable, FULL_SPEED)
        try:
            for attribute, value in settings.items():
                write(device, attribute, value)
            for attribute, value in settings.items():
                actual = read(device, attribute)
                if actual != value:
                    raise RuntimeError(f"{attribute} read back {actual}, expected {value}")
        except (OSError, RuntimeError, ValueError):
            write(device, enable, FULL_SPEED)
            raise

    def main():
        device = find_controller()
        # Sensor indices can change when the firmware enables different inputs.
        labels = [
            label for label in device.glob("temp*_label")
            if label.read_text().strip() == SENSOR
        ]
        if len(labels) != 1:
            raise RuntimeError(f"Expected one {SENSOR} temperature source")
        sensor = int(labels[0].name.removeprefix("temp").removesuffix("_label"))
        desired = {
            channel: curve_settings(channel, sensor) for channel in CHANNELS
        }
        # Read every attribute before changing any channel.
        needs_update = [
            channel for channel, settings in desired.items()
            if {attribute: read(device, attribute) for attribute in settings} != settings
        ]
        for channel in needs_update:
            apply_channel(device, channel, desired[channel])
        if needs_update:
            print(f"Restored Q-Fan settings on PWM channels {needs_update}")
        else:
            print(f"Q-Fan settings already match on PWM channels {list(CHANNELS)}")

    if __name__ == "__main__":
        main()
  '';
in
{
  boot.kernelModules = [ "nct6775" ];

  systemd.services.ivpc-fan-curve = {
    description = "Restore IVPC motherboard fan curves";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.python3}/bin/python3 ${applyCurve}";
    };
  };
}
