#!/bin/sh
# fetch-alpine-openrc.sh — estrae APKBUILD + init scripts da Alpine aports
# per convertirli in servizi dinit.
#
# Uso:
#   ./scripts/fetch-alpine-openrc.sh              # tutti i target
#   ./scripts/fetch-alpine-openrc.sh dbus avahi   # solo lista specifica
#   APORTS_BRANCH=edge ./scripts/fetch-alpine-openrc.sh  # ramo alternativo

set -eu
CACHE_DIR="references/alpine-aports"
OUT_DIR="references/alpine-openrc"
BRANCH="${APORTS_BRANCH:-3.24-stable}"

# flag CLI per ramo alternativo
if [ "${1:-}" = "--edge" ]; then
	BRANCH="master"; shift
elif [ "${1:-}" = "--branch" ]; then
	BRANCH="${2:?missing branch name}"; shift 2
fi

# 1. clone/update aports
if [ ! -d "$CACHE_DIR/.git" ]; then
	echo "Cloning Alpine aports ($BRANCH, shallow)..."
	mkdir -p "$(dirname "$CACHE_DIR")"
	git clone --depth 1 --filter=blob:none --branch "$BRANCH" \
		https://gitlab.alpinelinux.org/alpine/aports.git "$CACHE_DIR"
else
	echo "Updating Alpine aports ($BRANCH)..."
	git -C "$CACHE_DIR" fetch --depth 1 origin "$BRANCH"
	git -C "$CACHE_DIR" reset --hard "origin/$BRANCH"
fi

# 2. lista target (può venire da argomenti o lista completa)
if [ $# -gt 0 ]; then
	TARGETS="$*"
else
	# tutti i pacchetti con init script openrc (lista manuale, aggiornabile)
	TARGETS="acpid apparmor avahi btrfs-progs busybox busybox-mdev chrony
cpufrequtils cronie cryptsetup cups dbus dnsmasq earlyoom elogind eudev
firewalld fuse fwupd greetd incus incus-feature incus-feature-agent
iptables irqbalance kbd lxc nftables nix openssh-server-common pipewire
podman polkit rasdaemon rsync smartmontools udisks2 udev-init-scripts
vector wireplumber xdg-desktop-portal xdg-desktop-portal-wlr
xdg-document-portal"
fi

mkdir -p "$OUT_DIR"

# 3. per ogni target: trova la dir negli aports, copia APKBUILD + *.initd + *.confd
found=0; missing=0
for pkg in $TARGETS; do
	# cerca: prima nome esatto, poi -openrc, poi senza -openrc
	dir=""
	for candidate in "$pkg" "${pkg}-openrc" "${pkg%-openrc}"; do
		[ -d "$CACHE_DIR/community/$candidate" ] && dir="$CACHE_DIR/community/$candidate" && break
		[ -d "$CACHE_DIR/main/$candidate" ] && dir="$CACHE_DIR/main/$candidate" && break
	done
	if [ -z "$dir" ]; then
		echo "MISSING: $pkg (not in community/main)"
		missing=$((missing + 1))
		continue
	fi
	dest="$OUT_DIR/$pkg"
	mkdir -p "$dest"
	cp "$dir/APKBUILD" "$dest/" 2>/dev/null || true
	cp "$dir"/*.initd "$dest/" 2>/dev/null || true
	cp "$dir"/*.confd "$dest/" 2>/dev/null || true
	cp "$dir"/*.patch "$dest/" 2>/dev/null || true
	files=$(ls -1 "$dest" 2>/dev/null | wc -l)
	echo "OK: $pkg ($files files from $(basename "$(dirname "$dir")")/)"
	found=$((found + 1))
done

echo ""
echo "Done: $found extracted, $missing missing (in aports $BRANCH)"
echo "Output: $OUT_DIR/ (gitignored)"
