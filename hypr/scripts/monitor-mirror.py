#!/usr/bin/env python3
"""Temporary Hyprland mirroring, supervised by monitor-session.sh."""

import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def run(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or f"{args[0]} failed")
    return result.stdout.strip()


def monitors():
    result = json.loads(run("hyprctl", "-j", "monitors", "all"))
    if not isinstance(result, list):
        raise RuntimeError("Hyprland did not return a monitor list")
    return result


def mirror_of(monitor):
    value = monitor.get("mirrorOf")
    return "" if value in (None, "", "none") else value


def usable(monitor):
    return (not monitor.get("disabled", False) and not mirror_of(monitor)
            and monitor.get("width", 0) > 0 and monitor.get("height", 0) > 0)


def identity(monitor):
    return [monitor.get(key, "") for key in ("name", "make", "model", "serial")]


def spec(monitor):
    """Retain the mode, scale, rotation, position and exposed colour settings."""
    width, height = monitor.get("width", 0), monitor.get("height", 0)
    refresh = monitor.get("refreshRate", 0)
    mode = f"{width}x{height}@{refresh:.5f}" if width > 0 and height > 0 and refresh > 0 else "preferred"
    result = {
        "output": monitor["name"], "disabled": monitor.get("disabled", False),
        "mode": mode, "position": f"{monitor.get('x', 0)}x{monitor.get('y', 0)}",
        "scale": monitor.get("scale", 1) or 1, "transform": monitor.get("transform", 0),
        "mirror": mirror_of(monitor), "vrr": int(bool(monitor.get("vrr", False))),
    }
    for source, target in (
        ("colorManagementPreset", "cm"), ("sdrBrightness", "sdrbrightness"),
        ("sdrSaturation", "sdrsaturation"), ("sdrMinLuminance", "sdr_min_luminance"),
        ("sdrMaxLuminance", "sdr_max_luminance"),
    ):
        if source in monitor:
            result[target] = monitor[source]
    if "currentFormat" in monitor:
        result["bitdepth"] = 10 if "2101010" in monitor["currentFormat"] else 8
    return result


def lua(value):
    # JSON string escaping includes escapes Lua does not accept (e.g. \u).
    # Quote control bytes using Lua's fixed-width decimal escape instead.
    if isinstance(value, str):
        return '"' + ''.join(
            '\\' + char if char in ('"', '\\') else
            f"\\{ord(char):03d}" if ord(char) < 32 else char for char in value
        ) + '"'
    return json.dumps(value, allow_nan=False)


def apply(rule):
    body = ", ".join(f"{key} = {lua(value)}" for key, value in rule.items())
    response = run("hyprctl", "eval", "hl.monitor({ " + body + " })")
    if response not in ("", "ok"):
        raise RuntimeError(response)


def write_state(path, state):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(state) + "\n")
    temporary.replace(path)


def choose(header, choices):
    # Labels include the connector, keeping identical monitor models distinct.
    labels = {f"{m['name']} — {m.get('description') or m.get('model') or 'Display'}"
              + (" (disabled)" if m.get("disabled") else ""): m for m in choices}
    result = subprocess.run(["gum", "choose", "--header", header, "--", *labels],
                            text=True, stdout=subprocess.PIPE)
    if result.returncode or result.stdout.strip() not in labels:
        raise KeyboardInterrupt
    return labels[result.stdout.strip()]


def ensure_usable():
    connected = monitors()
    if not connected or any(usable(m) for m in connected):
        return
    candidate = next((m for m in connected if m["name"].startswith("eDP-")), connected[0])
    rule = spec(candidate)
    rule.update(disabled=False, mirror="", mode="preferred", position="auto", scale=1)
    apply(rule)


def stop(path):
    if not path.exists():
        return False
    state = json.loads(path.read_text())
    connected = monitors()
    original = state["receiver"]
    receiver = next((m for m in connected if m["name"] == original["name"]), None)
    if receiver is None or identity(receiver) == identity(original) or mirror_of(receiver) == state["source"]["name"]:
        rule = spec(original)
    else:
        # A different physical screen on the same connector must not inherit
        # the old screen's mode or rotation.
        rule = spec(receiver)
    rule["mirror"] = ""
    if receiver and rule["disabled"] and not any(usable(m) for m in connected if m != receiver):
        # The source may have been unplugged instead of the receiver. Never
        # restore a disabled receiver when it is the only screen left.
        rule.update(disabled=False, position="auto")
    apply(rule)  # Also clears the temporary rule for a disconnected receiver.
    ensure_usable()
    path.unlink()
    return True


def start(path, runtime):
    if not shutil.which("gum"):
        raise RuntimeError("gum is required for the screen picker")
    if path.exists():
        raise RuntimeError("Already mirroring; run 'monitor unmirror' first")
    connected = monitors()
    sources = [m for m in connected if usable(m)]
    if not sources or len(connected) < 2:
        raise RuntimeError("Connect a second screen and keep at least one screen enabled")
    source = choose("Which screen do you want to copy?", sources)
    receivers = [m for m in connected if m["name"] != source["name"]
                 and not mirror_of(m)]
    # Don't turn a source that already has other mirrors into another mirror.
    receivers = [m for m in receivers if not any(mirror_of(other) == m["name"] for other in connected)]
    if not receivers:
        raise RuntimeError("No independent receiver is available")
    receiver = choose("Which screen should show the copy?", receivers)
    state = {"source": source, "receiver": receiver}
    write_state(path, state)
    try:
        for _ in range(75):
            mode_file = runtime / "daemon-mode"
            if mode_file.exists() and mode_file.read_text().strip() == "mirror":
                break
            time.sleep(0.2)
        else:
            raise RuntimeError("Monitor session did not pause automatic management")
        # The daemon might have been applying a profile while the picker was
        # open. Snapshot the settled receiver after the daemon has stopped.
        connected = monitors()
        current = {m["name"]: m for m in connected}
        if any(m["name"] not in current or identity(current[m["name"]]) != identity(m)
               for m in (source, receiver)) or not usable(current[source["name"]]):
            raise RuntimeError("Screens changed during selection; run 'monitor mirror' again")
        receiver = current[receiver["name"]]
        state["receiver"] = receiver
        write_state(path, state)
        rule = spec(receiver)
        rule.update(disabled=False, mirror=source["name"])
        if receiver.get("disabled"):
            rule.update(mode="preferred", scale=1)
        apply(rule)
        for _ in range(20):
            current = {m["name"]: m for m in monitors()}
            target = current.get(receiver["name"], {})
            if (mirror_of(target) == source["name"] and not target.get("disabled", True)
                    and usable(current.get(source["name"], {}))):
                print(f"Mirroring {source['name']} onto {receiver['name']}. Stop with: monitor unmirror")
                return
            time.sleep(0.2)
        raise RuntimeError("Hyprland did not enable the requested mirror")
    except BaseException:
        stop(path)
        raise


def check(path):
    if not path.exists():
        return
    state = json.loads(path.read_text())
    connected = monitors()
    if not connected:
        return  # A transient query during sleep/wake must not end the session.
    current = {m["name"]: m for m in connected}
    source, receiver = state["source"], state["receiver"]
    live_source, live_receiver = current.get(source["name"]), current.get(receiver["name"])
    if (live_source is None or live_receiver is None
            or identity(live_source) != identity(source) or not usable(live_source)
            or mirror_of(live_receiver) != source["name"] or live_receiver.get("disabled")):
        stop(path)
        print("Temporary mirroring ended; previous management mode restored.")


def main():
    runtime = Path(os.environ["XDG_RUNTIME_DIR"]) / "hypr-monitor-ui"
    runtime.mkdir(parents=True, exist_ok=True)
    action = sys.argv[1]
    with (runtime / "mirror.lock").open("w") as lock:
        # The session must keep running while start() awaits its acknowledgement.
        flags = fcntl.LOCK_EX | (fcntl.LOCK_NB if action == "check" else 0)
        try:
            fcntl.flock(lock, flags)
        except BlockingIOError:
            return
        path = runtime / "mirror.json"
        if action == "start":
            start(path, runtime)
        elif action == "stop":
            if stop(path):
                print("Mirroring stopped; previous management mode restored.")
        elif action == "check":
            check(path)
        else:
            raise RuntimeError(f"Unknown mirror action: {action}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"monitor: {error}", file=sys.stderr)
        sys.exit(1)
