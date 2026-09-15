#!/bin/sh
# fetch-alpine-openrc.sh — estrae gli init script OpenRC da Alpine aports
# per convertirli in servizi dinit
#
# Uso:
#   ./scripts/fetch-alpine-openrc.sh                 # clone/update aports in references/alpine-aports
#   ./scripts/fetch-alpine-openrc.sh dbus chrony     # estrae solo servizi specifici
#
# I file finiscono in references/alpine-openrc/<pkg>/ (gitignored)
# Vedi docs/CONVERSION.md per la guida di conversione

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

# se argomenti dati, estrae solo quelli, altrimenti tutti i *-openrc
if [ $# -gt 0 ]; then
	pkgs="$*"
else
	# trova tutti i pacchetti che hanno un file *.initd
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

echo "Done. File in $OUT_DIR/ (gitignored, vedi .gitignore: references/)"
echo "Per convertire vedi docs/CONVERSION.md"
