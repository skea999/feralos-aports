#!/bin/sh
# generate-dinit-services.sh — genera pacchetti dinit da init scripts OpenRC estratti
#
# Legge references/alpine-openrc/<pkg>/<pkg>.initd e genera src/<pkg>-dinit/
# con service file + APKBUILD per ogni servizio nella mapping list.

BASE="/home/skem/Progetti/skeaAlpineInstaller/references/feralos-aports"
ALPINE="$BASE/references/alpine-openrc"
SRC="$BASE/src"

# Mapping: openrc-name|dinit-name|command|depends-on-target|alpine-depends
# command: se vuoto, viene estratto dall'init script
# depends-on: local.target | network.target | login.target
# alpine-depends: pacchetto/alpine che fornisce il binario

count=0
while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    openrc_name=$(echo "$entry" | cut -d'|' -f1)
    dinit_name=$(echo "$entry" | cut -d'|' -f2)
    command=$(echo "$entry" | cut -d'|' -f3)
    depends_on=$(echo "$entry" | cut -d'|' -f4)
    alpine_dep=$(echo "$entry" | cut -d'|' -f5)

    [ -z "$depends_on" ] && depends_on="local.target"

    outdir="$SRC/$dinit_name"

    # Skip if already exists
    if [ -d "$outdir" ]; then
        echo "SKIP  (exists)"
        continue
    fi

    mkdir -p "$outdir"

    # Extract command from Alpine openrc if command is empty
    if [ -z "$command" ]; then
        initd=$(find "$ALPINE" -path "*/$openrc_name/*.initd" 2>/dev/null | head -1)
        if [ -n "$initd" ]; then
            command=$(grep -m1 '^command=' "$initd" 2>/dev/null | cut -d= -f2-)
            command=${command#\"}
            command=${command%\"}
        fi
        [ -z "$command" ] && { echo "SKIP $dinit_name: no command found"; rmdir "$outdir"; continue; }
    fi

    # Determine restart policy (one-shot vs daemon)
    restart="true"

    # Create service file
    cat > "$outdir/$dinit_name" <<SVCEOF
# dinit service: $dinit_name (converted from openrc $openrc_name)
type = process
command = $command
restart = $restart
depends-on = $depends_on
SVCEOF

    # Create APKBUILD
    cat > "$outdir/APKBUILD" <<KBUILDEOF
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
KBUILDEOF

    count=$((count + 1))
    echo "CREATED: $dinit_name (cmd: $command)"
done <<'MAPPING'
greetd|greetd-dinit|greetd||greetd
polkit|polkit-dinit|polkitd||polkit
pipewire|pipewire-dinit|pipewire||pipewire
wireplumber|wireplumber-dinit|wireplumber||wireplumber
avahi|avahi-dinit|avahi-daemon||avahi
firewalld|firewalld-dinit|firewalld||firewalld
cups|cups-dinit|cupsd||cups
xdg-desktop-portal|xdg-desktop-portal-dinit|xdg-desktop-portal||xdg-desktop-portal
xdg-desktop-portal-wlr|xdg-desktop-portal-wlr-dinit|xdg-desktop-portal-wlr||xdg-desktop-portal-wlr
xdg-document-portal|xdg-document-portal-dinit|xdg-document-portal||xdg-document-portal
elogind|elogind-dinit|elogind||elogind
rsync|rsync-dinit|rsync --daemon||rsync
smartmontools|smartmontools-dinit|smartd||smartmontools
rasdaemon|rasdaemon-dinit|rasdaemon||rasdaemon
udisks2|udisks2-dinit|udisksd||udisks2
cpufrequtils|cpufrequtils-dinit|cpufreqd||cpufrequtils
nix|nix-dinit|nix-daemon||nix
dnsmasq|dnsmasq-dinit|dnsmasq||dnsmasq
iptables|iptables-dinit|iptables-restore||iptables
nftables|nftables-dinit|nft -f /etc/nftables.conf||nftables
lxc|lxc-dinit|lxc-start --name systemd --daemon||lxc
podman|podman-dinit|podman system service -f||podman
apparmor|apparmor-dinit|aa-notify -p /etc/apparmor.d/notify.conf||apparmor
fuse|fuse-dinit|fusermount -V||fuse
btrfs-progs|btrfs-progs-dinit|btrfs device scan||btrfs-progs
MAPPING

echo "Created $count services"
