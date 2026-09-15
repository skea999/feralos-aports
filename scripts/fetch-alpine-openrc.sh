#!/bin/sh
# fetch-alpine-openrc.sh — extracts OpenRC init scripts from Alpine aports
# to convert them into dinit services
#
# Usage:
#   ./scripts/fetch-alpine-openrc.sh                 # clone/update aports (3.24-stable) in references/alpine-aports
#   ./scripts/fetch-alpine-openrc.sh --edge          # usa edge (master)
#   ./scripts/fetch-alpine-openrc.sh --branch 3.23-stable dbus  # ramo specifico
#   ./scripts/fetch-alpine-openrc.sh dbus chrony     # extracts specific services only
#   APORTS_BRANCH=edge ./scripts/fetch-alpine-openrc.sh  # via env var
#
# I file finiscono in references/alpine-openrc/<pkg>/ (gitignored)
# See docs/CONVERSION.md for the conversion guide

set -eu
REPO_URL="https://gitlab.alpinelinux.org/alpine/aports.git"
CACHE_DIR="references/alpine-aports"
OUT_DIR="references/alpine-openrc"
# ramo stabile di Alpine da cui estrarre (coerente con FeralOS branch: latest-stable)
BRANCH="${APORTS_BRANCH:-3.24-stable}"

# CLI flag for an alternative branch
if [ "${1:-}" = "--edge" ]; then
	BRANCH="master"
	shift
elif [ "${1:-}" = "--branch" ]; then
	BRANCH="${2:?missing branch name}"
	shift 2
fi

if [ ! -d "$CACHE_DIR/.git" ]; then
	echo "Cloning Alpine aports ($BRANCH, shallow)..."
	mkdir -p "$(dirname "$CACHE_DIR")"
	git clone --depth 1 --filter=blob:none --branch "$BRANCH" "$REPO_URL" "$CACHE_DIR"
else
	echo "Updating Alpine aports ($BRANCH)..."
	git -C "$CACHE_DIR" fetch --depth 1 origin "$BRANCH"
	git -C "$CACHE_DIR" reset --hard "origin/$BRANCH"
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
