#!/bin/sh
# fetch-alpine-openrc.sh — extracts OpenRC init scripts from Alpine aports
# to convert them into dinit services
#
# Usage:
#   ./scripts/fetch-alpine-openrc.sh                 # clone/update aports in references/alpine-aports
#   ./scripts/fetch-alpine-openrc.sh dbus chrony     # extracts specific services only
#
# I file finiscono in references/alpine-openrc/<pkg>/ (gitignored)
# See docs/CONVERSION.md for the conversion guide

set -eu
REPO_URL="https://gitlab.alpinelinux.org/alpine/aports.git"
CACHE_DIR="references/alpine-aports"
OUT_DIR="references/alpine-openrc"

if [ ! -d "$CACHE_DIR/.git" ]; then
	echo "Cloning Alpine aports (shallow)..."
	mkdir -p "$(dirname "$CACHE_DIR")"
	git clone --depth 1 --filter=blob:none "$REPO_URL" "$CACHE_DIR"
else
	echo "Updating Alpine aports..."
	git -C "$CACHE_DIR" fetch --depth 1 origin master
	git -C "$CACHE_DIR" reset --hard origin/master
fi

mkdir -p "$OUT_DIR"

# if arguments given, extracts those only, otherwise all *-openrc
if [ $# -gt 0 ]; then
	pkgs="$*"
else
	# find all packages that have an *.initd file
	pkgs=$(find "$CACHE_DIR" -name "*.initd" -exec dirname {} \; | xargs -I{} basename {} | sort -u)
fi

for pkg in $pkgs; do
	# cerca il pacchetto negli aports (main/community/testing)
	found=$(find "$CACHE_DIR" -type d -name "$pkg" | head -1)
	if [ -z "$found" ]; then
		# prova con suffisso -openrc
		found=$(find "$CACHE_DIR" -type d -name "${pkg}-openrc" | head -1)
		[ -z "$found" ] && found=$(find "$CACHE_DIR" -type d -name "${pkg%-openrc}" | head -1)
	fi
	if [ -z "$found" ]; then
		echo "WARN: $pkg non trovato"
		continue
	fi
	# copia APKBUILD + *.initd + *.confd
	dest="$OUT_DIR/$pkg"
	mkdir -p "$dest"
	cp -v "$found"/APKBUILD "$dest"/ 2>/dev/null || true
	cp -v "$found"/*.initd "$dest"/ 2>/dev/null || true
	cp -v "$found"/*.confd "$dest"/ 2>/dev/null || true
	cp -v "$found"/*.patch "$dest"/ 2>/dev/null || true
	echo " -> $pkg: $(ls -1 "$dest" | tr '\n' ' ')"
done

echo "Done. File in $OUT_DIR/ (gitignored, see .gitignore: references/)"
echo "For conversion see docs/CONVERSION.md"
