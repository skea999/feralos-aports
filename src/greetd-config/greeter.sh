#!/bin/sh
# FeralOS greeter dispatcher (ADR-013).
# greetd-config ships the COMMON config (vt 7) and this entry point; the
# DE-specific greeter script ships with the DE config package:
#   dms-config   -> /etc/greetd/greeter-niri.sh   (niri)
#   wayle-config -> /etc/greetd/greeter-wayle.sh  (niriWayle)
# Distinct filenames on purpose: the two DE packages are mutually exclusive
# on an install, but they must not collide as package content (the aports
# smoke-install installs every built package into one root).
for s in /etc/greetd/greeter-niri.sh /etc/greetd/greeter-wayle.sh; do
	[ -x "$s" ] && exec "$s"
done
echo 'feralos-greeter: no DE greeter script installed (dms-config or wayle-config)' >&2
exit 1
