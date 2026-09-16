#!/bin/sh
# generate-services.sh — generate dinit packages from scripts/services/
#
# scripts/services/<name> = dinit service file. The file IS the source of truth.
# Edit it to change the service. Create a new file to add a service.
#
# File format: dinit service definition + one metadata comment:
#   # alpine-dep: <alpine-package-name>     (used for APKBUILD depends)
#
# The generator creates src/<name>-dinit/{APKBUILD, <name>} for each file.
#
# Usage:
#   ./scripts/generate-services.sh              # generate all
#   ./scripts/generate-services.sh --check      # verify only, no writes

set -e
BASE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$BASE/src"
SERVICES_DIR="$BASE/scripts/services"

[ -d "$SERVICES_DIR" ] || { echo "no scripts/services/ dir"; exit 1; }

found=0; errors=0

for svc_path in "$SERVICES_DIR"/*; do
    [ -f "$svc_path" ] || continue
    name=$(basename "$svc_path")
    outdir="$SRC/${name}-dinit"
    apkbuild="$outdir/APKBUILD"

    # extract alpine-dep from metadata comment
    alpine_dep=$(grep -m1 '^# alpine-dep:' "$svc_path" 2>/dev/null | sed 's/^# alpine-dep: *//')
    [ -z "$alpine_dep" ] && alpine_dep="$name"

    if [ "${1:-}" = "--check" ]; then
        if [ ! -f "$outdir/$name" ]; then
            echo "MISSING: $outdir/$name"
            errors=$((errors + 1))
        elif ! sh -n "$outdir/$name" 2>/dev/null; then
            echo "SYNTAX:  $outdir/$name"
            errors=$((errors + 1))
        fi
        continue
    fi

    mkdir -p "$outdir"

    # copy service file (is the dinit service, as-is)
    cp "$svc_path" "$outdir/$name"

    # generate APKBUILD
    cat > "$apkbuild" <<APKBUILD_EOF
# Contributor: FeralOS <dev@feralos.org>
# Maintainer: FeralOS <dev@feralos.org>
pkgname=${name}-dinit
pkgver=0.1.0
pkgrel=0
pkgdesc="dinit service for $name"
url="https://github.com/skea999/feralos-aports"
arch="all"
license="ISC"
depends="dinit $alpine_dep"
makedepends=""
source="$name"

build() { return 0; }
check() { return 0; }

package() {
	install -Dm644 "\$srcdir/$name" "\$pkgdir/usr/lib/dinit.d/$name"
	mkdir -p "\$pkgdir/usr/lib/dinit.d/boot.d"
	ln -sf "../$name" "\$pkgdir/usr/lib/dinit.d/boot.d/$name"
}

sha512sums="REPLACE_ME  $name"
APKBUILD_EOF

    found=$((found + 1))
    echo "OK: ${name}-dinit"
done

# compute sha512sums for new/updated packages
if [ "${1:-}" != "--check" ]; then
    updated=0
    for svc_dir in "$SRC"/*-dinit; do
        [ -d "$svc_dir" ] || continue
        pkg=$(basename "$svc_dir")
        apkbuild="$svc_dir/APKBUILD"
        [ -f "$apkbuild" ] || continue
        grep -q 'REPLACE_ME' "$apkbuild" || continue
        svc_file="$svc_dir/$pkg"  # pkg = name-dinit, svc file = name
        base_name=${pkg%-dinit}
        svc_file="$svc_dir/$base_name"
        [ -f "$svc_file" ] || continue
        H=$(sha256sum "$svc_file" 2>/dev/null | awk '{print $1}') || continue
        sed -i "s/REPLACE_ME/$H/" "$apkbuild"
        updated=$((updated + 1))
    done
    echo ""
    echo "Checksums updated: $updated"
fi

echo ""
echo "=== Done: $found packages, $errors errors ==="
