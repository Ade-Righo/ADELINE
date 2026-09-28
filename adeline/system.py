#!/usr/bin/env python3
import os
import platform
import shutil
import subprocess
from typing import Dict, List, Any


def run_command(cmd: List[str], sudo: bool = False, capture: bool = True) -> Dict[str, Any]:
    full_cmd = []
    if sudo:
        full_cmd = ["sudo", "-n"]
    full_cmd.extend(cmd)
    try:
        result = subprocess.run(full_cmd, capture_output=capture, text=True, timeout=25)
        return {
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
        }
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return {"returncode": 1, "stdout": "", "stderr": str(exc)}


def get_system_snapshot() -> Dict[str, Any]:
    host = {
        "hostname": platform.node(),
        "os": platform.system() + " " + platform.release(),
        "kernel": platform.uname().release,
        "cpu": platform.processor() or "Unknown CPU",
        "ram": "unknown",
        "disk": "unknown",
    }

    mem = run_command(["free", "-m"])
    if mem["returncode"] == 0:
        lines = mem["stdout"].splitlines()
        if len(lines) >= 2:
            tokens = lines[1].split()
            if len(tokens) >= 3:
                total = int(tokens[1])
                used = int(tokens[2])
                host["ram"] = f"{used} MiB / {total} MiB ({int(used / total * 100) if total else 0}%)"

    disk = run_command(["df", "-h", "/"])
    if disk["returncode"] == 0:
        lines = disk["stdout"].splitlines()
        if len(lines) >= 2:
            vals = lines[1].split()
            if len(vals) >= 5:
                host["disk"] = f"{vals[2]} used / {vals[1]} total ({vals[4]} available)"

    waydroid = {
        "service_status": "unknown",
        "socket": "missing",
        "session": "missing",
        "adb": "unknown",
        "binder": "unknown",
        "ui": "not_detected",
    }

    service = run_command(["systemctl", "is-active", "waydroid-container"])
    if service["returncode"] == 0:
        waydroid["service_status"] = service["stdout"]
    else:
        waydroid["service_status"] = service["stdout"] or "inactive"

    socket = os.path.exists("/run/waydroid.socket")
    waydroid["socket"] = "present" if socket else "missing"

    session = run_command(["pgrep", "-af", "waydroid.*session"])
    waydroid["session"] = "running" if session["stdout"] else "not_running"

    adb = run_command(["adb", "devices"])
    if adb["returncode"] == 0:
        devices = [line for line in adb["stdout"].splitlines() if "device" in line and "List" not in line]
        waydroid["adb"] = str(len(devices)) + " device(s)" if devices else "no devices"
    else:
        waydroid["adb"] = "not_installed"

    binder = run_command(["lsmod"])
    if binder["returncode"] == 0 and "binder" in binder["stdout"]:
        waydroid["binder"] = "loaded"
    else:
        waydroid["binder"] = "not_loaded"

    ui = run_command(["pgrep", "-af", "waydroid show|hwcomposer"])
    waydroid["ui"] = "running" if ui["stdout"] else "not_running"

    return {"host": host, "waydroid": waydroid}
