#!/bin/sh
# generate-services.sh — source of truth for all dinit services
#
# Architecture:
#   - SERVICE_LIST (below): hardcoded list of all services to convert
#   - Each entry: openrc_name|dinit_name|command|depends_on|alpine_dep
#   - Generated files go to src/<dinit_name>/ (service + APKBUILD)
#   - Overrides: src/<dinit_name>/_override/ (files here REPLACE generated ones)
#   - To ADD a service: append a line to SERVICE_LIST
#   - To MODIFY a service: create src/<name>/_override/custom-service
#   - To UPDATE upstream: run scripts/fetch-alpine-openrc.sh, then rerun this
#
# Usage:
#   ./scripts/generate-services.sh              # regenerate all from list
#   ./scripts/generate-services.sh --check      # verify only, no writes
#
# After running: compute sha512sums, commit, push.

set -e
BASE="$(cd "$(dirname "$0")/.." && pwd)"
ALPINE="$BASE/references/alpine-openrc"
SRC="$BASE/src"
MODE="${1:-generate}"

# ============================================================
# SERVICE LIST — single source of truth
# Format: openrc_name | dinit_name | command (empty=extract) | depends_on | alpine_dep
# Add new services here. Remove = remove from src/.
# ============================================================
cat << 'SERVICES_EOF' > /tmp/_svc_list.txt
acpid|acpid-dinit||local.target|acpid
apparmor|apparmor-dinit||local.target|apparmor
avahi|avahi-dinit||local.target|avahi
btrfs-progs|btrfs-progs-dinit||local.target|btrfs-progs
busybox-mdev|busybox-mdev-dinit|/sbin/mdev -s|local.target|busybox
chrony|chrony-dinit||network.target|chrony
cpufrequtils|cpufrequtils-dinit||local.target|cpufrequtils
cronie|cronie-dinit||local.target|cronie
cups|cups-dinit||local.target|cups
dbus|dbus-dinit||local.target|dbus
dnsmasq|dnsmasq-dinit||local.target|dnsmasq
earlyoom|earlyoom-dinit||local.target|earlyoom
elogind|elogind-dinit||local.target|elogind
firewalld|firewalld-dinit||local.target|firewalld
fuse|fuse-dinit||local.target|fuse
fwupd|fwupd-dinit||local.target|fwupd
greetd|greetd-dinit||local.target|greetd
incus|incus-dinit||local.target|incus
incus-feature-agent|incus-feature-agent-dinit||local.target|incus-feature
iptables|iptables-dinit||local.target|iptables
irqbalance|irqbalance-dinit||local.target|irqbalance
lxc|lxc-dinit||local.target|lxc
nftables|nftables-dinit||local.target|nftables
nix|nix-dinit||local.target|nix
openssh|openssh-dinit||network.target|openssh
pipewire|pipewire-dinit||local.target|pipewire
podman|podman-dinit||local.target|podman
polkit|polkit-dinit||local.target|polkit
rasdaemon|rasdaemon-dinit||local.target|rasdaemon
rsync|rsync-dinit||local.target|rsync
smartmontools|smartmontools-dinit||local.target|smartmontools
udisks2|udisks2-dinit||local.target|udisks2
vector|vector-dinit||local.target|vector
wireplumber|wireplumber-dinit||local.target|wireplumber
xdg-desktop-portal|xdg-desktop-portal-dinit||local.target|xdg-desktop-portal
xdg-desktop-portal-wlr|xdg-desktop-portal-wlr-dinit||local.target|xdg-desktop-portal-wlr
xdg-document-portal|xdg-document-portal-dinit||local.target|xdg-document-portal
SERVICES_EOF

# ============================================================
# EXTRACTION (fetch-alpine-openrc if needed)
# ============================================================
if [ ! -d "$ALPINE" ] || [ -z "$(ls -A "$ALpine" 2>/dev/null)" ]; then
    echo "Extracting Alpine openrc files..."
    "$BASE/scripts/fetch-alpine-openrc.sh" >/dev/null 2>&1
fi

# ============================================================
# GENERATION
# ============================================================
found=0; skipped=0; errors=0

while IFS='|' read -r openrc_name dinit_name command depends_on alpine_dep; do
    # skip empty/comment lines
    [ -z "$openrc_name" ] && continue
    case "$openrc_name" in \#*) continue ;; esac

    outdir="$SRC/$dinit_name"
    override="$outdir/_override"
    svc_file="$outdir/$dinit_name"
    apkbuild="$outdir/APKBUILD"

    # --check mode: verify only, no writes
    if [ "$MODE" = "--check" ]; then
        if [ ! -f "$svc_file" ]; then
            echo "MISSING: $dinit_name/$dinit_name"
            errors=$((errors + 1))
        elif ! sh -n "$svc_file" 2>/dev/null; then
            echo "SYNTAX:  $dinit_name/$dinit_name"
            errors=$((errors + 1))
        fi
        continue
    fi

    # extract command from Alpine openrc if not provided
    if [ -z "$command" ]; then
        initd=$(find "$ALPINE" -path "*/$openrc_name/*.initd" 2>/dev/null | head -1)
        if [ -n "$initd" ]; then
            command=$(grep -m1 '^command=' "$initd" | sed 's/^command=//;s/"//g;s/^ *//;s/ *$//')
        fi
        [ -z "$command" ] && { echo "SKIP $dinit_name: no command found in $openrc_name"; errors=$((errors + 1)); continue; }
    fi

    depends_on="${depends_on:-local.target}"
    mkdir -p "$outdir"

    # write service file (unless overridden)
    if [ ! -f "$svc_file" ] || [ ! -d "$override" ]; then
        cat > "$svc_file" <<EOF
# dinit service: $dinit_name (generated from openrc $openrc_name)
type = process
command = $command
restart = true
depends-on = $depends_on
EOF
    fi

    # apply overrides (if any)
    if [ -d "$override" ]; then
        for f in "$override"/*; do
            [ -f "$f" ] || continue
            cp "$f" "$outdir/$(basename "$f")"
        done
    fi

    # write APKBUILD (always regenerated — idempotent)
    cat > "$apkbuild" <<EOF
# Contributor: FeralOS <dev@feralos.org>
# Maintainer: FeralOS <dev@feralos.org>
pkgname=$dinit_name
pkgver=0.1.0
pkgrel=0
pkgdesc="dinit service for $openrc_name"
url="https://github.com/skea999/feralos-aports"
arch="all"
license="ISC"
depends="dinit $alpine_dep"
makedepends=""
source="$dinit_name"

build() { return 0; }
check() { return 0; }

package() {
    install -Dm644 "\$srcdir/$dinit_name" "\$pkgdir/usr/lib/dinit.d/$dinit_name"
    mkdir -p "\$pkgdir/usr/lib/dinit.d/boot.d"
    ln -sf ../"$dinit_name" "\$pkgdir/usr/lib/dinit.d/boot.d/$dinit_name"
}

sha512sums="REPLACE_ME  $dinit_name"
EOF

    found=$((found + 1))
    echo "OK: $dinit_name"
done < /tmp/_svc_list.txt

# ============================================================
# CHECKSUMS (compute sha512 for new/updated service files)
# ============================================================
if [ "$MODE" = "generate" ]; then
    updated=0
    for svc_dir in "$SRC"/*-dinit; do
        [ -d "$svc_dir" ] || continue
        pkg=$(basename "$svc_dir")
        svc="$svc_dir/$pkg"
        apkbuild="$svc_dir/APKBUILD"
        [ -f "$svc_file" ] || continue
        [ -f "$apkbuild" ] || continue
        grep -q 'REPLACE_ME' "$apkbuild" || continue
        H=$(sha256sum "$svc" 2>/dev/null | awk '{print $1}') || continue
        sed -i "s/REPLACE_ME/$H/" "$apkbuild"
        updated=$((updated + 1))
    done
    echo ""
    echo "Checksums updated: $updated"
fi

# cleanup
rm -f /tmp/_svc_list.txt

echo ""
echo "=== Done: $found generated, $errors errors ==="
echo "Run: git diff --stat src/*-dinit/"
