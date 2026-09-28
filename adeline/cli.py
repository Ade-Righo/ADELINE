#!/usr/bin/env python3
import argparse
import os
import sys
from typing import Optional

from adeline.system import get_system_snapshot
from adeline.waydroid import diagnose_waydroid, safe_repair_waydroid

RESET = "\033[0m"
BOLD = "\033[1m"
CYAN = "\033[36m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
RED = "\033[31m"


def color(text: str, code: str) -> str:
    return f"{code}{text}{RESET}"


def render_status(report):
    print(color("ADELINE - Linux Helper", CYAN + BOLD))
    print(color("=" * 48, CYAN))
    print(f"Host: {report['host']['hostname']}")
    print(f"OS: {report['host']['os']}")
    print(f"Kernel: {report['host']['kernel']}")
    print(f"CPU: {report['host']['cpu']}")
    print(f"RAM: {report['host']['ram']}" )
    print(f"Disk: {report['host']['disk']}")
    print("\nWaydroid: ")
    print(f"  Service: {report['waydroid']['service_status']}")
    print(f"  Socket: {report['waydroid']['socket']}")
    print(f"  Session: {report['waydroid']['session']}")
    print(f"  ADB: {report['waydroid']['adb']}")
    print(f"  Binder: {report['waydroid']['binder']}")
    print(f"  UI: {report['waydroid']['ui']}")


def render_report(issues):
    if not issues:
        print(color("No issues detected.", GREEN))
        return 0

    print(color("Issues detected:", YELLOW))
    for issue in issues:
        sev = issue["severity"]
        if sev == "ERROR":
            sev_code = RED
        elif sev == "WARNING":
            sev_code = YELLOW
        else:
            sev_code = CYAN
        print(f"- [{color(sev, sev_code)}] {issue['module']} : {issue['message']}")
    return 1


def interactive_menu():
    while True:
        print(color("\nADELINE Menu", CYAN + BOLD))
        print("1. Status")
        print("2. Diagnose")
        print("3. Repair safely")
        print("4. Exit")
        choice = input("Choose an option [1-4]: ").strip()

        if choice == "1":
            report = get_system_snapshot()
            render_status(report)
            input("\nPress Enter to continue...")
        elif choice == "2":
            issues = diagnose_waydroid()
            render_report(issues)
            input("\nPress Enter to continue...")
        elif choice == "3":
            confirm = input("This will try safer fixes for Waydroid. Continue? [y/N]: ").strip().lower()
            if confirm in {"y", "yes"}:
                result = safe_repair_waydroid()
                print(result)
            else:
                print("Repair cancelled.")
            input("\nPress Enter to continue...")
        elif choice == "4":
            break
        else:
            print("Invalid option.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="ADELINE Linux Assistant")
    parser.add_argument("command", nargs="?", default="menu", help="status | diagnose | repair | menu")
    return parser


def main(argv=None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    command = args.command.lower()

    if command == "status":
        report = get_system_snapshot()
        render_status(report)
        return 0

    if command == "diagnose":
        issues = diagnose_waydroid()
        return render_report(issues)

    if command == "repair":
        result = safe_repair_waydroid()
        print(result)
        return 0

    if command == "menu":
        interactive_menu()
        return 0

    if command == "--help" or command == "-h":
        parser.print_help()
        return 0

    print(color(f"Unknown command: {command}", RED))
    parser.print_help()
    return 1
