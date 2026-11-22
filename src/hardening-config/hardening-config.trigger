#!/bin/sh
# FeralOS: a kernel cmdline fragment changed (any package) — reassemble
# /etc/kernel/cmdline and rebuild the installed UKI. Generic (watches
# /etc/kernel/cmdline.d). Install-time guarded: SetupBoot assembles itself.
[ -f /etc/kernel/cmdline.d/00-base.conf ] || exit 0
/usr/sbin/assemble-cmdline || exit 0
for m in /lib/modules/*; do
	[ -d "$m" ] || continue
	NEW_VERSION=${m##*/lib/modules/}
	k=$(ls /boot/vmlinuz-* 2>/dev/null | head -1)
	[ -n "$k" ] || continue
	FLAVOR=${k##*/vmlinuz-}
	FLAVOR=${FLAVOR%-$NEW_VERSION}
	FLAVOR=$FLAVOR NEW_VERSION=$NEW_VERSION /etc/kernel-hooks.d/50-booster.hook || true
done
exit 0
