#!/usr/bin/env python3
import os
import shutil
import subprocess
from typing import Dict, List

from adeline.system import get_system_snapshot


def _issue(module: str, severity: str, message: str) -> Dict[str, str]:
    return {"module": module, "severity": severity, "message": message}


def diagnose_waydroid() -> List[Dict[str, str]]:
    issues: List[Dict[str, str]] = []
    snapshot = get_system_snapshot()
    waydroid = snapshot["waydroid"]

    if waydroid["service_status"] not in {"active", "activating"}:
        issues.append(_issue("waydroid-container", "ERROR", "Waydroid service is not active."))

    if waydroid["socket"] == "missing":
        issues.append(_issue("waydroid-socket", "WARNING", "Socket /run/waydroid.socket is missing."))

    if waydroid["session"] == "not_running":
        issues.append(_issue("waydroid-session", "ERROR", "Waydroid session is not running."))

    if waydroid["binder"] == "not_loaded":
        issues.append(_issue("kernel-module", "ERROR", "Kernel binder module is not loaded."))

    if waydroid["adb"] == "not_installed":
        issues.append(_issue("adb", "ERROR", "ADB is not installed or not available."))
    elif waydroid["adb"] == "no devices":
        issues.append(_issue("adb", "WARNING", "ADB has no active devices."))

    if shutil.which("waydroid") is None:
        issues.append(_issue("waydroid-binary", "ERROR", "Waydroid binary is missing from PATH."))

    if not os.path.isdir("/var/lib/waydroid"):
        issues.append(_issue("waydroid-data", "WARNING", "Waydroid data directory is missing."))

    return issues


def safe_repair_waydroid() -> str:
    report = ["ADELINE safe repair started."]

    if os.geteuid() != 0:
        report.append("This repair requires sudo privileges; retry with sudo or root.")
        return "\n".join(report)

    if shutil.which("systemctl"):
        subprocess.run(["systemctl", "start", "waydroid-container"], check=False)
        report.append("Started waydroid-container service if present.")

    if not os.path.exists("/run/waydroid.socket"):
        try:
            os.remove("/run/waydroid.socket")
        except FileNotFoundError:
            pass
        report.append("Cleared stale Waydroid socket if it existed.")

    if shutil.which("modprobe"):
        for module in ("binder_linux", "ashmem_linux"):
            subprocess.run(["modprobe", module], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        report.append("Ensured binder/ashmem modules are loaded where available.")

    if os.path.isdir("/var/lib/waydroid"):
        os.makedirs("/var/lib/waydroid/data/media/0/Download", exist_ok=True)
        os.makedirs("/var/lib/waydroid/data/media/0/Documents", exist_ok=True)
        os.makedirs("/var/lib/waydroid/data/media/0/Pictures", exist_ok=True)
        report.append("Ensured default Waydroid media directories exist.")

    if shutil.which("waydroid"):
        subprocess.run(["waydroid", "session", "start"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        report.append("Attempted to start the Waydroid session.")

    final = diagnose_waydroid()
    if not final:
        report.append("Validation: no issues were detected after the safe repair pass.")
    else:
        report.append("Validation: issues still remain; review outputs from `adeline diagnose`.")

    return "\n".join(report)
