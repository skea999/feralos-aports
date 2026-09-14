# Dinit Packages (FeralOS aports)

> Sources verified 2026-09-10. APKBUILD drafts mirror Chimera's own cports template
> (`main/dinit-chimera/template.py`) translated to Alpine abuild.

## Repo Layout (nested in skeaAlpineInstaller, own .git + tags)

```
feralos-aports/
├── abuild.conf                     # PACKAGER_PRIVKEY path
├── feralos.pub                     # public key (repo signing)
├── sd-tools/
│   └── APKBUILD
├── dinit-chimera/
│   ├── APKBUILD
│   ├── dinit-devd                  # [FeralOS] eudev hook (mandatory)
│   ├── dinit-cryptdisks            # [FeralOS] crypttab hook
│   └── sysctl/10-feralos.conf      # hardening sysctls (port from hardening feature)
└── .gitea/workflows/build.yml      # CI: build → index → pages
```

## Alpine Packages Used As-Is (rule 0 — prefer Alpine, always)

| Package | Repo | Role |
|---------|------|------|
| `dinit` 0.21.0 | community | PID 1, `dinitctl`; `dinit-shutdown/halt/reboot/soft-reboot/poweroff` (built `--shutdown-prefix=dinit-`) |
| **`sd-tools` 0.99.0-r3** | **community (v3.24 + edge)** | `sd-tmpfiles` + `sd-sysusers` — ⚠️ our APKBUILD was REMOVED (superseded, rule 0); history in git |
| `snooze` 0.6 | community | timer for `tmpfiles-clean` service |
| `eudev` | main | udevd (`/sbin/udevd`) + udevadm (drives `dinit-devd` hook) |
| `kmod` | main | libkmod for compiled helpers |
| `util-linux` | main | mount(8) `-a` semantics, fsck, sulogin (verify provider) |
| `tzdata` | main | tzdb |
| `meson`, `kmod-dev`, `linux-headers` | main | makedepends |

## sd-tools APKBUILD — ⚠️ SUPERSEDED (rule 0: use Alpine's)

> **Do not build.** Alpine community ships `sd-tools 0.99.0-r3` (v3.24 + edge,
> maintainer Achill Gilgenast) providing `cmd:sd-tmpfiles` + `cmd:sd-sysusers`.
> Our APKBUILD was removed from the active tree (kept in git history). The draft
> below remains as reference / pipeline proof documentation.

Upstream: C (gnu11) meson project, **only tag `v0.99.0`**, deps `libcap`
(required) + `libacl` (boolean option `acl`), tests option available.
Binaries: `sd-tmpfiles` (src/tmpfiles), `sd-sysusers` (src/sysusers).

```bash
maintainer="FeralOS <dev@feralos.org>"
pkgname=sd-tools
pkgver=0.99.0                       # only upstream tag (2024-02)
pkgrel=0
pkgdesc="Standalone systemd tmpfiles and sysusers utilities"
url="https://github.com/chimera-linux/sd-tools"
arch="all"
license="LGPL-2.1+"
makedepends="meson libcap-dev acl-dev linux-headers"  # GCC — libstdc++ n/a (C code)
source="$pkgname-$pkgver.tar.gz::https://github.com/chimera-linux/sd-tools/archive/refs/tags/v$pkgver.tar.gz"

build() {
	# policy: optional PACKAGE acl-dev is mandatory (rule 5); the FEATURE is
	# enabled best-effort — droppable only if build breaks AND boot doesn't need it
	abuild-meson -Dacl=enabled -Dtests=true . output
	meson compile -C output
}

check() {
	meson test -C output
}

package() {
	DESTDIR="$pkgdir" meson install --no-rebuild -C output
}
```

## dinit-chimera APKBUILD (draft)

```bash
maintainer="FeralOS <dev@feralos.org>"
pkgname=dinit-chimera
pkgver=0.99.24                      # bump = update whole boot suite
pkgrel=0
pkgdesc="Dinit core service suite (Chimera upstream) for FeralOS"
url="https://github.com/chimera-linux/dinit-chimera"
arch="all"
license="BSD-2-Clause"
depends="dinit sd-tools snooze eudev tzdata util-linux-misc"
makedepends="meson kmod-dev linux-headers"
subpackages="$pkgname-doc"
source="$pkgname-$pkgver.tar.gz::https://github.com/chimera-linux/dinit-chimera/archive/refs/tags/v$pkgver.tar.gz
	dinit-devd
	dinit-cryptdisks"
options="!check"                    # upstream has no test suite

build() {
	# plain meson setup (NOT abuild-meson: it auto-passes --sbindir which
	# conflicts with our -Dsbindir=bin)
	# -Dsbindir=bin: upstream hardcodes dinit_path=$prefix/sbindir/dinit while
	# Alpine installs dinit to /usr/bin/dinit — bin keeps the @DINIT_PATH@
	# substitution correct; the only other sbin file (init wrapper) is
	# relocated in package() anyway
	# -Ddinit-sulogin-path: busybox sulogin on Alpine (upstream default is
	# /usr/sbin/sulogin)
	meson setup \
		--prefix=/usr \
		--buildtype=plain \
		-Ddefault-path-env=/usr/bin \
		-Dsbindir=bin \
		-Ddinit-sulogin-path=/sbin/sulogin \
		. output
	meson compile -C output
}

package() {
	DESTDIR="$pkgdir" meson install --no-rebuild -C output

	# init wrapper: meson installs it to /usr/bin/init (sbindir=bin) —
	# relocate for OpenRC coexistence; kernel cmdline uses
	# init=/usr/libexec/dinit/init
	mkdir -p "$pkgdir/usr/libexec/dinit"
	mv "$pkgdir/usr/bin/init" "$pkgdir/usr/libexec/dinit/init"

	install -Dm755 "$srcdir/dinit-devd"      "$pkgdir/usr/libexec/dinit-devd"
	install -Dm755 "$srcdir/dinit-cryptdisks" "$pkgdir/usr/libexec/dinit-cryptdisks"

	# hardening sysctls (ported from FeralOS hardening feature)
	install -Dm644 "$srcdir/10-feralos.conf" "$pkgdir/usr/lib/sysctl.d/10-feralos.conf"
}
```

### meson options consumed (upstream `meson_options.txt`)

`bless-boot-path`, `dinit-console-path`, `dinit-cryptdisks-path`, `dinit-devd-path`,
`dinit-sulogin-path`, `default-path-env`. Unset options fall back to upstream defaults
(`/usr/libexec/…`, sulogin `/usr/sbin/sulogin`).

### What the package installs (upstream, no maintenance on our side)

```
/usr/lib/dinit.d/                  # 52+1 service files (boot, system, early-*, targets…)
/usr/lib/dinit.d/early/scripts/    # ~35 shell scripts (@SCRIPT_PATH@-substituted)
/usr/lib/dinit.d/early/helpers/    # 12 SEPARATE small binaries (see table below)
/usr/lib/dinit.d/man/              # man pages
/usr/lib/tmpfiles.d/               # dinit.conf, utmp.conf
/usr/lib/sysctl.d/                 # upstream defaults
```

### Compiled helpers (early/helpers/meson.build — one executable per .cc)

| Binary | What it does (source-verified) | Notes |
|--------|-------------------------------|-------|
| `mnt` | **multicall** (`mnt-service` symlink): `prepare` (all pseudo-fs + root remount + propagation in one shot), `root-rw` (fstab-aware remount), `supervise` (supervised mount via /proc/self/mounts poll → powers `.mount` services), `try`/`rmnt`/`umnt`/`getent`/`is`. Loop devices, `UUID=`/`LABEL=`, fallback to `/sbin/mount.<fstype>` | **NOT replaceable with `mount`** — zero external deps |
| `kmod` | loads `/etc/modules` + `modules-load.d/` post-root | the only one linking **libkmod**; complements booster (initramfs ≠ runtime) |
| `hwclock` / `swclock` | RTC / swclock, shared semantics (`clock_common.hh`) | busybox/util-linux equivalents exist but are not swappable without patching upstream scripts |
| `sysctl` | sysctl.d processing with precedence | equivalent: `util-linux sysctl --system`; same reason to keep it |
| `swap` | fstab swapon/off | — |
| `seedrng` | persistent RNG seeding | — |
| `lo` | loopback up | — |
| `binfmt` | registers binfmt.d | — |
| `zram` | zram setup from dinit-zram.conf | — |
| `devmon` + `devclient` | **dummy** device monitor (`-none` provider) | replaceable by a real udev monitor in the future |

**uutils compatibility**: helpers = pure C++ syscalls (zero coreutils); scripts = `awk`/`grep`/`sed`/`mkdir`/`mount -a` — restricted POSIX, zero GNU-vs-BSD diverging flags. Upstream runs on **chimerautils** (C port of BSD utilities from FreeBSD) and is tested on GNU and busybox too — README: *"We test chimerautils. Others are supported (GNU, busybox, etc.)"*. The POSIX common denominator covers **uutils** (bug-for-bug GNU) without friction; fallback: busybox, already present on Alpine.

## dinit-devd hook [FeralOS — the one mandatory glue file]

Per dinit-chimera README contract (start/stop/settle/trigger):

```sh
#!/bin/sh
# FeralOS: eudev backend for dinit-chimera device management
# paths VERIFIED from Alpine eudev APKBUILD: --sbindir=/sbin --bindir=/bin
case "$1" in
    start)  exec /sbin/udevd --daemon ;;
    stop)   /bin/udevadm control -e ;;
    settle) exec /bin/udevadm settle ;;
    trigger) exec /bin/udevadm trigger --action=add ;;
esac
echo "unknown action: $1" >&2
exit 1
```

> Resolved: `udevd` = `/sbin/udevd`, `udevadm` = `/bin/udevadm` (eudev builds with
> `--sbindir=/sbin --bindir=/bin`; Chimera's `/usr/libexec/udevd` is systemd-udevd
> and does not apply to eudev).

## dinit-cryptdisks hook [FeralOS]

For non-root dmcrypt (`/etc/crypttab`, e.g. LUKS swap on raid0 — root LUKS stays in
booster initramfs, untouched):

```sh
#!/bin/sh
# FeralOS: /etc/crypttab handling (early= or remaining= / start|stop)
[ -r /etc/crypttab ] || exit 0
case "$1-$2" in
    early-start|remaining-start)
        while read -r name dev key opts; do
            case "$name" in ''|'#'*) continue ;; esac
            cryptsetup open "$dev" "$name" ${key:+--key-file "$key"} || exit 1
        done < /etc/crypttab ;;
    *-stop)
        while read -r name dev key opts; do
            case "$name" in ''|'#'*) continue ;; esac
            cryptsetup close "$name" || true
        done < /etc/crypttab ;;
esac
```

(Semantics mirror Chimera's documented hook: arg1 = `early|remaining`, arg2 = `start|stop`.
Refine against `early/scripts/cryptdisks.sh` at impl time.)

## turnstile (Phase 4 — 4th upstream package, chimera-linux org)

Session/login tracker, originally `dinit-userservd`: spawns `dinit --user` at
login. Dinit backend = upstream reference (requires dinit ≥0.16; Alpine 0.21 ✓).
Base: the Alpine edge/testing APKBUILD (ptrcnull — same maintainer as dinit), adapted.

```bash
maintainer="FeralOS <dev@feralos.org>"
pkgname=turnstile
pkgver=0.1.11                       # track upstream tags
pkgrel=0
pkgdesc="Session/login tracker with dinit user service support"
url="https://github.com/chimera-linux/turnstile"
arch="all"
license="BSD-2-Clause"
depends="dinit elogind"             # elogind = seat/power; turnstile = sessions
makedepends="linux-pam-dev meson scdoc"
subpackages="$pkgname-doc"
source="$pkgname-$pkgver.tar.gz::https://github.com/chimera-linux/turnstile/archive/refs/tags/v$pkgver.tar.gz
	no-system-dinit.patch"          # from Alpine edge testing (Alpine quirks already solved)

build() {
	abuild-meson -Db_lto=true -Ddinit=enabled -Dmanage_rundir=true . output
	meson compile -C output
}

package() {
	DESTDIR="$pkgdir" meson install --no-rebuild -C output
	# turnstiled system service: upstream ships an example dinit service —
	# install it instead of Alpine's turnstiled.initd (OpenRC)
	# TODO(impl): verify upstream example path; enable via boot.d symlink
}
```

Installs: `turnstiled` (daemon, root), `pam_turnstile.so`, backend `dinit`
(shell script), `turnstiled.conf` (`backend = dinit`, `manage_rundir = true`).

**PAM setup (installer-side, Phase 4):**
- turnstiled PAM stack: `session optional pam_elogind.so` → elogind registers the
  session (seat/power stay with elogind)
- display manager PAM (greetd/sddm): `session optional pam_turnstile.so`

**What it solves:** `XDG_RUNTIME_DIR`, post-logout lingering, D-Bus session bus
export (`dinitctl setenv` in the user dbus service), **DMS as a real dinit user
service** (replaces the OpenRC async hack in `desktops/niri.go`).

**polkit caveat — RESOLVED with patch (decided):** user service processes (DMS
reboot/poweroff) live in the `turnstiled` PAM session (no seat) → `allow_active`
denied without a patch. Fix: Chimera's `turnstile.patch`
(cports `main/polkit/patches/turnstile.patch`, q66 2023, 1 hunk in
`polkitbackendsessionmonitor-systemd.c` — session whose service is `turnstiled`
→ ignore and fall back to `sd_uid_get_display`). **Versions aligned**: Chimera
polkit 127 = Alpine **v3.24/community** polkit 127-r2 (edge identical: same
build, same commit — coherent with our `branch: latest-stable`) → our aports
carries `polkit` (Alpine 127-r2 APKBUILD copy + patch; use the
`polkit-elogind` sub-package). The PAM file MUST be named exactly `turnstiled`
(upstream default ✓). Phases 1-3: patch NOT needed (dormant without turnstile).

**Verified: Alpine does NOT have the patch** — `community/polkit/` in aports
contains only APKBUILD + pam + initd (zero `patches/`); logical proof: Chimera
on the **same version 127** still carries the patch → if upstream 127 had it,
Chimera would have dropped it. Alpine's `-r2` is packaging-only (variant split,
openrc script).

## Future: `*-dinit` service packages (Phase 3)

Convention — files only, no scripts:

```bash
pkgname=sshd-dinit
depends="dinit-chimera openssh"

package() {
	install -Dm644 sshd "$pkgdir"/usr/lib/dinit.d/sshd
	mkdir -p "$pkgdir"/usr/lib/dinit.d/boot.d
	ln -s /usr/lib/dinit.d/sshd "$pkgdir"/usr/lib/dinit.d/boot.d/sshd
}
```

`system` service picks `boot.d` up via `waits-for.d` — same mechanism Chimera uses for
its own packages.
