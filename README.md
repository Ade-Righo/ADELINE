# ADELINE

ADELINE is a Linux system helper for Waydroid and desktop health monitoring.

Features:
- Safe Waydroid diagnostics
- Automatic issue detection
- Safe system repairs for Waydroid-related problems
- Quick installation into /usr/local/bin as a global command
- CLI dashboard for status, diagnosis, and repair

Quick install:

```bash
chmod +x install.sh
./install.sh
```

Then run:

```bash
adeline status
adeline diagnose
adeline repair
```

Important:
- ADELINE repairs only the Waydroid environment and host Linux system resources needed for it to run.
- It does not modify Android system partitions or unsafe host system files.
- Any destructive action still requires explicit user confirmation.

