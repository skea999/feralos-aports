#!/bin/sh
# generate-services.sh — generate dinit packages from scripts/services/ + Alpine openrc
#
# scripts/services/<name> = manifest + overrides for each service.
#   Empty file = auto-convert from Alpine .initd (command, restart, deps = defaults)
#   File with content = overrides to apply (key=value dinit service lines)
#
# The Alpine .initd (from fetch-alpine-openrc.sh) provides the base:
#   command, command_args → dinit "command ="
#   depend() { need/after } → mapped to dinit targets
#
# Output: src/<name>-dinit/{APKBUILD, <name>} for each service.

set -e
BASE="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$BASE/src"
SERVICES_DIR="$BASE/scripts/services"
ALPINE_DIR="$BASE/references/alpine-openrc"

[ -d "$SERVICES_DIR" ] || { echo "no scripts/services/ dir"; exit 1; }

found=0; errors=0; skipped=0

for manifest in "$SERVICES_DIR"/*; do
    [ -f "$manifest" ] || continue
    name=$(basename "$manifest")
    outdir="$SRC/${name}-dinit"

    # extract alpine-dep from manifest (mandatory)
    alpine_dep=$(grep -m1 '^alpine-dep' "$manifest" 2>/dev/null | sed 's/^alpine-dep[ =:]*//' | tr -d ' ')
    if [ -z "$alpine_dep" ]; then
        echo "SKIP $name: no alpine-dep in manifest"
        skipped=$((skipped + 1))
        continue
    fi

    # skip services already handled by dinit-chimera early boot chain
    # (creating a dinit service would conflict with the early chain)
    if grep -q '^covered-by: dinit-chimera' "$manifest" 2>/dev/null; then
        echo "SKIP $name: covered by dinit-chimera"
        skipped=$((skipped + 1))
        continue
    fi

    # read overrides from manifest (lines that are not comments/alpine-dep)
    overrides=$(grep -v '^#' "$manifest" | grep -v '^alpine-dep' | grep -v '^\s*$' || true)

    # read Alpine .initd for base command extraction
    initd=$(find "$ALPINE_DIR" -path "*/$name/*.initd" 2>/dev/null | head -1)
    base_command=""
    if [ -n "$initd" ]; then
        base_command=$(grep -m1 '^command=' "$initd" | sed 's/^command=//;s/"//g;s/^ *//;s/ *$//')
        base_args=$(grep -m1 '^command_args=' "$initd" | sed 's/^command_args=//;s/"//g;s/^ *//;s/ *$//')
        [ -n "$base_args" ] && base_command="$base_command $base_args"
    fi

    mkdir -p "$outdir"

    # ---- build the dinit service file ----
    if [ -z "$overrides" ]; then
        # pure auto-generation from Alpine .initd
        {
            echo "# dinit service: $name (auto-generated from Alpine openrc $name)"
            echo "type = process"
            # guard: OpenRC script-based initd units have no command= line —
            # emitting an empty command makes the service invalid
            [ -n "$base_command" ] && echo "command = $base_command"
            echo "restart = true"
            echo "depends-on = local.target"
        } > "$outdir/$name"
    else
        # apply overrides: start from defaults, then replace/add override lines
        # defaults
        svc_type="process"
        svc_command="$base_command"
        svc_restart="true"
        svc_depends="local.target"

        # apply overrides line by line
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            case "$line" in
                type*=*)    svc_type=${line#type = };;
                type=*)     svc_type=${line#type=};;
                command*=*) svc_command=${line#command = };;
                command=*)  svc_command=${line#command=};;
                restart*=*) svc_restart=${line#restart = };;
                restart=*)  svc_restart=${line#restart=};;
                depends-on*=*) svc_depends=${line#depends-on = };;
            esac
        done <<EOF
$overrides
EOF

        {
            echo "# dinit service: $name (Alpine openrc $name + overrides)"
            echo "type = $svc_type"
            # command only makes sense for process/scripted services —
            # milestone services must not carry an empty command line
            [ -n "$svc_command" ] && echo "command = $svc_command"
            echo "restart = $svc_restart"
            echo "depends-on = $svc_depends"
        } > "$outdir/$name"
    fi

    # ---- generate APKBUILD ----
    cat > "$outdir/APKBUILD" <<APKBUILD_EOF
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
	# Alpine model: ship the service file; enablement is rules-driven (dinitctl enable)
	install -Dm644 "\$srcdir/$name" "\$pkgdir/lib/dinit.d/$name"
}

sha512sums="REPLACE_ME  $name"
APKBUILD_EOF

    # compute sha512 (sha512sums= requires sha512, not sha256)
    H=$(sha512sum "$outdir/$name" 2>/dev/null | awk '{print $1}')
    [ -n "$H" ] && sed -i "s/REPLACE_ME/$H/" "$outdir/APKBUILD"

    found=$((found + 1))
    echo "OK: ${name}-dinit (alpine-dep: $alpine_dep)"
done

echo ""
echo "=== Done: $found generated, $skipped skipped, $errors errors ==="
