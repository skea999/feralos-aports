# OpenRC → Dinit Conversion (Phase 3+)

> Scope: system/desktop services only. **Early boot is not converted — it ships ready
> in `dinit-chimera`.** Verified against upstream docs (DINIT-AS-INIT, dinit-chimera README).

## Estrazione sorgenti OpenRC da Alpine aports

Prima di convertire un servizio, estrai i suoi file originali:

```sh
# prima volta: clona aports + estrae TUTTI i servizi openrc
./scripts/fetch-alpine-openrc.sh

# oppure solo servizi specifici
./scripts/fetch-alpine-openrc.sh dbus chrony sddm
```

I file finiscono in `references/alpine-openrc/<pkg>/` (APKBUILD + `*.initd` + `*.confd`):

```
references/alpine-openrc/dbus/
  APKBUILD
  dbus.initd          # ← init script OpenRC da convertire
  dbus.confd          #    config opzionale
```

La cartella `references/` è **gitignored** (vedi `.gitignore: references/`): è cache locale,
non va committata. Rigenerala quando serve con lo script sopra.

Cosa guardare nell'`*.initd`:

| OpenRC | Cosa cercare | Dinit |
|--------|--------------|-------|
| `command=` | binario + path | `command =` |
| `command_args` | argomenti | appendi a `command` |
| `command_background=true` + `pidfile=` | supervisione | `type = process` (dinit supervisiona) |
| `depend()` { `need` / `after` / `before` } | dipendenze | `depends-on:` verso target (vedi tabella sotto) |
| `start()` / `stop()` custom | logica speciale | script `type = scripted` se necessario |

Dopo l'estrazione, crea il pacchetto `-dinit` in `src/<name>-dinit/` seguendo i template sotto.

## Rules

1. One package per service: `<name>-dinit`, depends on `dinit-chimera` + daemon pkg.
2. Service file → `/lib/dinit.d/<name>`; enable = symlink in `/lib/dinit.d/boot.d/`.
   (Alpine standard: stock dinit does NOT scan `/usr/lib/dinit.d`.)
3. `type = process` is **supervised** — no `command_background`, no pidfiles, no
   start-stop-daemon. Foreground flags on the daemon.
4. Depend on upstream targets, never on other distro services:
   - fs-writable daemons → `depends-on: local.target`
   - network daemons → `depends-on: network.target`
   - clock-dependent → `waits-for: time-sync.target`
   - login-screen → `depends-on: login.target`
5. One console service at a time: `runs-on-console` only for interactive; use
   `shares-console` for output-only. Avoid `after:`/`before:` — prefer
   `depends-on:` / `waits-for:` (upstream guidance).
6. Prefer `restart = true` for daemons; `restart = false` for oneshots (`type = scripted`).

## Conversion Table (OpenRC init.d → dinit service)

| OpenRC construct | Dinit equivalent |
|---|---|
| `command=` + `command_background=true` + `pidfile=` | `type = process`, `command = <daemon --foreground-flags>` |
| `depend() { need net }` | `depends-on: network.target` |
| `depend() { need localmount }` / `after bootmisc` | `depends-on: local.target` |
| `depend() { use logger }` | drop (vector is `local.target`-ordered) |
| `rc-update add X default` | symlink `boot.d/X` (package does it) |
| `start_pre()` (mkdir /var/run/…) | tmpfiles.d entry (sd-tmpfiles) or wrapper `-c 'mkdir … && exec daemon'` |
| `keyword -stop` | nothing (supervised stop is built-in) |
| `supervise-daemon` | nothing (native supervision) |

## FeralOS Service Conversions

### dbus
```ini
type = process
command = /usr/bin/dbus-daemon --system --nofork
restart = true
depends-on: local.target
```
(system bus socket at `/run/dbus/system_bus_socket` — consumers just depend on dbus.)

### sshd (needs host keys pre-generated)
```ini
type = process
command = /usr/sbin/sshd -D -e
restart = true
depends-on: network.target
```
Host-key generation: keep installer-side (already generates keys) — not a boot task.

### chronyd
```ini
type = process
command = /usr/sbin/chronyd -d -s
restart = true
depends-on: network.target
```
Consumers needing clock: `waits-for: time-sync.target` (upstream target exists for this).

### cronie
```ini
type = process
command = /usr/sbin/crond -f -S
restart = true
depends-on: local.target
```

### acpid / irqbalance / earlyoom
```ini
type = process
command = /usr/sbin/acpid -f
restart = true
depends-on: local.target
```
(same shape for `irqbalance --foreground`, `earlyoom -r 60`.)

### vector (+ vector-setup one-shot)
```ini
# vector-setup: scripted, populates /run/vector socket dir
type = scripted
command = /usr/libexec/vector-setup
depends-on: local.target
```
```ini
# vector
type = process
command = /usr/bin/vector --config /etc/vector/vector.toml
restart = true
depends-on: local.target
waits-for: vector-setup
```

### incusd
```ini
type = process
command = /usr/libexec/incus/incusd --group incus-admin
restart = true
depends-on: local.target
```
(verify exact foreground invocation at impl time; OpenRC script has it.)

### elogind / seatd (desktop — Phase 4)
Mutually exclusive (Alpine wiki rule, same as today). `seatd` variant for cosmic,
`elogind` for niri/kde:
```ini
# elogind
type = process
command = /usr/lib/elogind/elogind
restart = true
depends-on: dbus
depends-on: local.target
```
elogind sotto dinit: comprovato da Chimera — daemon init-agnostico (dbus + cgroups
gestiti da `early-cgroups` upstream).

### turnstile (Phase 4 — niri, optional for other DEs)
`turnstiled` = root-supervised system service (upstream ships an example dinit
service):
```ini
# turnstiled
type = process
command = /usr/bin/turnstiled
restart = true
depends-on: dbus
depends-on: local.target
```
- elogind owns seat/power; turnstile owns sessions + lingering + `dinit --user`
- PAM integration: `pam_elogind` in the turnstiled stack,
  `pam_turnstile.so` in the display manager PAM
- **DMS becomes a user service** (`~/.config/dinit.d/`) — the current OpenRC async
  hack (`desktops/niri.go`, wait wayland socket) can be removed: with turnstile the
  wayland socket exists before the login prompt (the `ready` backend step waits for
  the first user services before completing login)
- Caveat: polkit sees a non-local session (Chimera patches polkit) — evaluate in
  the desktop phase

### Display managers (Phase 4)
`greetd` (niri), `cosmic-greeter` (cosmic; requires seatd), `sddm` (kde):
`depends-on: login.target` + seat provider + dbus. DMS service in
`chrootPhase/desktops/niri.go` gains a dinit variant (waits for user wayland socket —
same async pattern as the current OpenRC script; with turnstile it becomes a user
service instead).

## Validation Checklist (per service)

```sh
dinitcheck /lib/dinit.d/<name>         # syntax
dinitctl start <name>                  # live start
dinitctl status <name>                 # state + exit info
dinitctl stop <name> && dinitctl start <name>   # restart cleanliness
```

Boot-level: service appears in `dinitctl status` output after reboot; no
`[FAILED]` on serial console for its line.

## Installer Impact (Phase 5)

`internal_rules.yaml` `services: {name: runlevel}` currently → `rc-update add`.
With `enableDinit`, service applier emits `boot.d` symlinks instead
(`logic.go`/services writer): map `default` → `/lib/dinit.d/boot.d/` symlink.
`boot`/`sysinit`-level OpenRC services (udev etc.) are **dropped** under dinit —
upstream early chain replaces them.
