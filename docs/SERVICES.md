# Dinit Service Files — Upstream Reference

> These are **Chimera upstream files** (`/usr/lib/dinit.d/`, v0.99.24). FeralOS does not
> write or maintain them — documented here as the reference our packages and `*-dinit`
> conversions must align with. Verified from `services/meson.build`.

## Complete Upstream Service List (52 + zram-device)

**Entry points**
- `boot` — `type=internal`, `depends-on: system`, `waits-for.d: /etc/dinit.d/boot.d`
- `system` — `type=internal`, `depends-on: login.target`, `depends-on: network.target`,
  `waits-for.d: /usr/lib/dinit.d/boot.d` ← **our packages symlink here**
- `recovery`, `single` — boot-failure shell / single-user (`chain-to` back to boot)

**Pseudo-fs & env**
- `early-env`, `early-pseudofs`, `early-tmpfs`, `early-machine-id`, `early-kernel-env`

**Modules**
- `early-modules-early`, `early-modules` → `early-modules.target`

**Devices** (distro hook)
- `early-devd`, `early-dev-trigger`, `early-dev-settle`, `early-devmon` → `early-devices.target`

**Clock**
- `early-hwclock`, `early-swclock`

**Storage**
- `early-cryptdisks-early`, `early-cryptdisks` (distro hook)
- `early-lvm`, `early-mdadm`, `early-dmraid`, `early-fs-btrfs`, `early-fs-zfs`
- `early-root-fsck`, `early-root-rw.target`
- `early-fs-fsck`, `early-fs-fstab.target`, `early-fs-local.target`, `early-fs-pre.target`
- `early-swap`

**System setup**
- `early-rng`, `early-sysctl`, `early-binfmt`, `early-cgroups`,
  `early-tmpfiles-dev`, `early-tmpfiles`, `early-tmpfiles-…`
- `early-console.target` (distro hook), `early-keyboard.target`
- `early-net-lo`, `early-hostname`
- `early-bless-boot`, `early-kdump` (optional kexec subpackage)

**Targets**
- `early-prepare.target`, `pre-local.target`, `local.target`,
  `pre-network.target`, `network.target`, `login.target`, `time-sync.target`

**Extras**
- `zram-device` (templated, `zram-device@zramN`, config via `/etc/dinit-zram.d/*.conf`)

## Key Upstream File Contents (verbatim, for reference)

**services/boot**
```
# This is the primary entry point. It triggers startup
# of every other service. In addition to that it also
# provides the user-enabled service directory.

type = internal
depends-on: system
waits-for.d: /etc/dinit.d/boot.d
```

**services/system**
```
# the actual primary chimera service

type = internal
depends-on: login.target
depends-on: network.target
waits-for.d: /usr/lib/dinit.d/boot.d
```

**services/early-pseudofs**
```
type = scripted
command = @SCRIPT_PATH@/pseudofs.sh
depends-on: early-env
```

**services/early-devd**
```
# run the early device manager; not supervised, meant to
# be replaced with a supervised service later in the boot

type = scripted
command = @SCRIPT_PATH@/dev.sh start
stop-command = @SCRIPT_PATH@/dev.sh stop
depends-on: early-prepare.target
depends-on: early-modules-early
depends-on: early-tmpfiles-dev
```

**services/early-root-rw.target**
```
type = scripted
command = @SCRIPT_PATH@/root-rw.sh
depends-ms: early-root-fsck
options: starts-rwfs
```
(`starts-rwfs` → dinit creates its control socket once root is writable.)

**early/scripts/tmpfiles.sh** — tolerance pattern worth copying for our services:
```sh
sd-tmpfiles "$@"
RET=$?
case "$RET" in
	65) exit 0 ;; # DATERR
	73) exit 0 ;; # CANTCREAT
	*) exit $RET ;;
esac
```

Meson substitution keys: `@EARLY_PATH@`, `@HELPER_PATH@`, `@SCRIPT_PATH@`,
`@DINIT_SULOGIN_PATH@` (format `cmake@`).

## FeralOS `*-dinit` Service Templates (Phase 3 — the only files we write)

**daemon on local fs** (cronie, acpid, irqbalance, earlyoom, vector, fwupd):
```
type = process
command = /usr/sbin/<daemon> <foreground-flags>
restart = true
depends-on: local.target
```

**network daemon** (sshd, chronyd):
```
type = process
command = /usr/sbin/<daemon> <flags>
restart = true
depends-on: network.target
```

**dbus first, then everything D-Bus**:
```
# dbus
type = process
command = /usr/bin/dbus-daemon --system --nofork
restart = true
depends-on: local.target
```
```
# elogind (or seatd — never both, same policy as OpenRC today)
type = process
command = /usr/lib/elogind/elogind
restart = true
depends-on: local.target
depends-on: dbus
```

**display manager** (greetd example):
```
type = process
command = /usr/bin/greetd
restart = true
depends-on: login.target
depends-on: dbus
```

OpenRC → Dinit dependency mapping:

| OpenRC (`depend()`) | Dinit |
|---|---|
| `need net` | `depends-on: network.target` |
| `need localmount` / `after bootmisc` | `depends-on: local.target` |
| runlevel `boot` | `depends-on: pre-local.target` (rarely needed) |
| runlevel `default` (rc-update add) | symlink in `/usr/lib/dinit.d/boot.d/` |
| `command_background=true` + pidfile | not needed — `type = process` is supervised |
| `keyword -stop` / `stop()` | `stop-command =` (rarely needed) |
