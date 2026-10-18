# D-Bus activation pattern (ADR-010)

FeralOS rule: every D-Bus-activatable daemon is a dinit service; D-Bus
activation is only a trigger that starts that unit. This repository ships the
mechanism (the `feralos-dbus-activate` shim + materializers) and every
override. Upstream package files are never modified.

FeralOS-repo counterparts: `docs/architecture/dbus-activation.md` (mechanism,
inventory, checklist) and `docs/architecture/boot-oneshots.md` (oneshot
pattern); decision record: ADR-010 in the feralos repository.

## The launch-helper gate (why /etc does not work)

The system bus activates through the setuid `dbus-daemon-launch-helper`. Its
config parser is the "trivial" one: it resolves service names ONLY against the
standard system service directories, in order:

1. `/usr/local/share/dbus-1/system-services`
2. `/usr/share/dbus-1/system-services`
3. `<datadir>/dbus-1/system-services` (usually `/usr/share`)
4. `/lib/dbus-1/system-services`

`/etc/dbus-1/system-services` and `/run/dbus-1/system-services` are loaded by
the daemon itself (they appear in `ListActivatableNames`) but are NEVER
searched by the helper — activation raw-spawns the `/usr/share` twin or fails
with `Spawn.ServiceNotFound` (live-verified on dbus 1.16.2).

abuild forbids packaging under `/usr/local`, so:

- system overrides ship in `/usr/share/feralos/dbus-system-services/` and the
  `dbus-services-setup` oneshot (both inits, ordered before dbus) copies them
  into `/usr/local/share/dbus-1/system-services` at boot;
- session overrides ship in `/usr/share/feralos/dbus-services/` and are
  materialized at login into `$XDG_RUNTIME_DIR/dbus-1/services` (no helper on
  the session bus — every servicedir is eligible).

## Adding a new activatable service

1. dinit unit `/lib/dinit.d/<Name>` — canonical bus name; wrapper+config
   pattern (ADR-008) for configurable daemons; `depends-on = dbus`.
2. Override `<Name>.service`:

   ```ini
   [D-BUS Service]
   Name=<Name>
   Exec=/usr/libexec/feralos/dbus-activate <Name> -- <upstream exec>
   User=root
   ```

   (`User=` is required by the helper.) Installed to
   `/usr/share/feralos/dbus-system-services/` (system) or
   `/usr/share/feralos/dbus-services/` (session) — NEVER
   `/etc/dbus-1/system-services`.
3. Aliases: separate `<Alias>.service` files with the same Exec target unit.
4. APKBUILD: `depends="feralos-dbus-activate"`, pkgrel bump, sha512sums
   (recompute; a sum bump must land in the SAME commit as its source files).
5. feralos repo: package list + `dinitServices` (only when the unit name
   differs from the OpenRC script name) + docs (inventory in
   `docs/architecture/dbus-activation.md`).
6. CI (build+deploy+client-test) → GitHub Pages. Verify the APKINDEX before
   harness runs (deploy race).

## Boot-time oneshot pattern (reference: `dbus-services-setup`)

Shipped by `feralos-dbus-activate` — copy this shape for any boot task that
must run before a consumer on BOTH inits:

- script `/usr/libexec/feralos/<name>-setup`: POSIX sh, busybox-safe,
  idempotent, self-healing, `exit 0` no-op, loud non-zero failure
  (reference: `src/feralos-dbus-activate/dbus-system-services-setup`)
- dinit unit `/lib/dinit.d/<name>`: `type = scripted` /
  `command = /usr/libexec/feralos/<name>-setup` / `before = <consumer>` /
  `depends-on = <consumer's dep, e.g. local.target>` / `restart = false`
  (reference: `src/feralos-dbus-activate/dbus-services-setup`)
- OpenRC initd `/etc/init.d/<name>`: `openrc-run`,
  `depend() { before <consumer> }`,
  `start() { ebegin ...; /usr/libexec/feralos/<name>-setup; eend $?; }`
  (reference: `src/feralos-dbus-activate/dbus-services-setup.initd`)
- SAME name on both inits; enabled from the feralos installer via
  `defaultRunlevels.boot` (rc-update always + dinit boot.d).

## Verifying on a target

- `dinitctl --system list | grep <unit>` / `rc-status --all`
- `dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListActivatableNames`
  — enumerated does not mean activatable
- trigger activation, then check the dinit started marker AND that the daemon
  environ has no `DBUS_STARTER_*` (raw helper spawns carry them; the shim
  excludes them): `tr '\0' '\n' < /proc/<pid>/environ | grep DBUS_STARTER_`
- the feralos harness enforces all of this: `dbus_activation_uniform` +
  `dbus_activation_env`
