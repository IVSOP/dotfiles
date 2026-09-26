# Hyprland monitor profiles

`ld1` is the laptop at desk 1: the Dell AW2725QF (serial `B49QC34`)
at 3840×2160, 120 Hz, scale 1.5, with the laptop panel disabled. hyprmoncfg
matches the Dell by make, model, and serial, even if its connector name changes.
`ld2` uses the same Dell settings at `1440x506`, with the LG ULTRAGEAR at its
preferred mode, scale 1, rotated 90 degrees at `0x0`. The laptop panel is off,
and the Dell remains the Waybar and Dunst display.
`d2` is the desktop version of `ld2`: it omits the laptop panel and uses the
Dell's preferred mode. `d2-1080` requests 1920×1080 at 330 Hz on the Dell,
at `1440x920` with scale 1.5, vertically centered beside the portrait LG.
Both keep the Dell as the Waybar and Dunst display.
`ldefault` uses only `eDP-1` at its preferred mode and scale 1. Its UI
selector is simply `eDP-1`. hyprmoncfg keeps the panel's make and model in
the saved profile because its automatic matcher uses hardware identities.
Saved output records omit connector names; post-apply scripts resolve the
current connectors from hardware identities or `eDP-1`.

The session starts `hyprmoncfgd` to select a saved profile on startup and on
monitor changes. Each profile is a named JSON file under `profiles/`. Its
`exec` command passes the main monitor's hardware identity to a post-apply script, which
resolves the current connector name and updates Waybar and Dunst. Generated
monitor rules live in `hypr/monitors.lua`; generated UI configs live under
`$XDG_RUNTIME_DIR/hypr-monitor-ui/`.

Waybar and Dunst theme files contain `MONITOR_NAME`. Launch scripts substitute
the selected connector into runtime copies; the source themes are templates.
Sway and i3 also render their own copies before starting Waybar or Dunst.

On this machine, `~/.config/hyprmoncfg` points to this directory so the normal
`hyprmoncfg` command also sees these profiles. Create that symlink on a new
machine after linking `~/.config/hypr` to this repo.

Use these commands to switch profiles:

```sh
~/.config/hypr/scripts/monitor-profile.sh profiles
~/.config/hypr/scripts/monitor-profile.sh apply ld1
~/.config/hypr/scripts/monitor-profile.sh apply ld2
~/.config/hypr/scripts/monitor-profile.sh apply ldefault
~/.config/hypr/scripts/monitor-profile.sh apply d2
~/.config/hypr/scripts/monitor-profile.sh apply d2-1080
~/.config/hypr/scripts/monitor-profile.sh auto
~/.config/hypr/scripts/monitor-profile.sh mode
```

Run `apply` from a terminal. It gives you 10 seconds to confirm a changed
layout before reverting. The selected layout stays in place until the set of
connected displays changes or you run `auto`. In automatic mode, `ld2` wins
when the Dell and LG are connected; `ld1` wins with only the Dell;
`ldefault` wins with neither external monitor connected.
`d2` and `d2-1080` describe the same connected hardware, so automatic matching
cannot distinguish them; select `d2-1080` manually when you want to force
330 Hz. The mode must appear in `hyprctl monitors all` on the desktop after
switching the Dell to FHD mode. `preferred` follows the mode the monitor reports
as preferred, which may change with its OSD setting, but does not guarantee
330 Hz.

hyprmoncfg converts underscores to hyphens in profile filenames. The 1080p
profile is therefore named `d2-1080`; the wrapper also accepts the old
`apply d2_1080` spelling.

hyprmoncfg 1.9.1's TUI marks `preferred` as "unsupported" because it compares
the literal word against the monitor's numeric mode list. The generated
Hyprland rule still uses `preferred`. Fixed-rate profiles use the exact mode
string reported by `hyprctl monitors all` to avoid the same false warning.

Use `monitor-profile.sh save another-name` to create more profiles.
For a new profile, set its `exec` field to
`~/.config/hypr/scripts/apply-monitor-ui.sh 'MAKE|MODEL|SERIAL'`, or pass a
stable connector name such as `eDP-1`. To disable all outputs except those
listed, use `apply-exclusive-monitor.sh` with the main display first, followed
by any other displays to keep on. The
`monitor-session.sh` loop also retries theme selection when Rofi-Themer starts
late, and it falls back to an available theme until the daemon responds.

Waybar starts or restarts after the monitor layout has stayed unchanged for
two seconds, avoiding a layer surface created during a mode change.

These profiles disable any other active output after applying.
