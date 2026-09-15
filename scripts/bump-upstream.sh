#!/bin/sh
# bump-upstream.sh — controlla se i pacchetti upstream hanno nuovi tag
# e genera un commit con pkgver + sha512 aggiornati.
#
# Uso:
#   ./scripts/bump-upstream.sh              # controlla tutti
#   ./scripts/bump-upstream.sh dinit-chimera  # solo un pacchetto
#
# Richiede: curl, sha256sum, git, abuild (per sha512sums)
# Non pusha — il push è manuale (o CI su push).

set -eu

BASE="/home/skem/Progetti/skeaAlpineInstaller/references/feralos-aports"
SRC="$BASE/src"
PKGS="${1:-dinit-chimera turnstile}"

bumped=0

for pkg in $PKGS; do
    apkdir="$SRC/$pkg"
    [ -f "$apkdir/APKBUILD" ] || { echo "SKIP $pkg (no APKBUILD)"; continue; }

    # leggi pkgver corrente
    current=$(grep '^pkgver=' "$apkdir/APKBUILD" | head -1 | cut -d= -f2)
    
    # trova ultimo tag upstream da GitHub API
    # dinit-chimera → chimera-linux/dinit-chimera
    # turnstile → chimera-linux/turnstile
    case "$pkg" in
        dinit-chimera) repo="chimera-linux/dinit-chimera" ;;
        turnstile)     repo="chimera-linux/turnstile" ;;
        *)             echo "SKIP $pkg (unknown repo)"; continue ;;
    esac
    
    latest=$(curl -sf "https://api.github.com/repos/$repo/tags?per_page=1" \
        | grep '"name"' | head -1 | sed 's/.*"name": *"v\?\([^"]*\)".*/\1/')
    
    [ -z "$latest" ] && { echo "SKIP $pkg (can't fetch tag)"; continue; }
    [ "$latest" = "$current" ] && { echo "OK $pkg (already at $current)"; continue; }
    
    echo "BUMP $pkg: $current → $latest"
    
    # aggiorna pkgver
    sed -i "s/^pkgver=.*/pkgver=$latest/" "$apkdir/APKBUILD"
    sed -i "s/^pkgrel=.*/pkgrel=0/" "$apkdir/APKBUILD"
    
    # riscarica tarball e ricalcola sha512
    tarball="$SRC/$pkg/$pkg-$latest.tar.gz"
    curl -fsSL "https://github.com/$repo/archive/refs/tags/v$latest.tar.gz" -o "$tarball"
    H=$(sha256sum "$tarball" | awk '{print $1}')
    
    # aggiorna sha512sums (solo la riga del tarball, non le righe hook)
    sed -i "s/^[a-f0-9]\{64\}  \$pkgname-\$pkgver\.tar\.gz/$H  \$pkgname-\$pkgver.tar.gz/" "$apkdir/APKBUILD"
    
    rm -f "$tarball"
    bumped=$((bumped + 1))
    echo "DONE $pkg: $current → $latest"
done

if [ "$bumped" -gt 0 ]; then
    echo ""
    echo "=== $bumped packages bumped ==="
    echo "Verifica: git diff --stat"
    echo "Dopo: git add -A && git commit -m 'bump: upstream updates'"
else
    echo "Nessun aggiornamento trovato"
fi
