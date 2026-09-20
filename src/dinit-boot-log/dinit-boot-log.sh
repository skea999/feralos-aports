#!/bin/sh
# FeralOS: persist the dinit status trail. dinit starts before /var/log is
# mounted (fstab) and before /var/log/dinit exists (tmpfiles) — PID1 writes
# to /run/dinit-boot.log (kernel cmdline: dinit_log_file=).
cp /run/dinit-boot.log /var/log/dinit/boot.log 2>/dev/null || true
exec tail -F /run/dinit-boot.log >> /var/log/dinit/boot.log 2>/dev/null
