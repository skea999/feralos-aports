# turnstile

Session/login tracker (`dinit-userservd` successor): spawns a per-user dinit
instance at login and tracks the login session. FeralOS needs it as the bridge
between PAM/greetd and the dinit **user** services (dbus, pipewire, DMS, ...).

- Base: Alpine **edge/testing** `turnstile 0.1.11-r2` (maintainer Patrycja Rosa),
  adapted — Alpine stable does not ship it.
- Upstream: https://github.com/chimera-linux/turnstile (v0.1.11 tarball).
- Version: `_upstream=0.1.11`, `pkgver=989.0.1.11` (989 override series, see
  below), `pkgrel=1`.

## Deviations from the Alpine reference

| Alpine | FeralOS | Why |
|--------|---------|-----|
| `no-system-dinit.patch` (strips upstream `data/dinit/turnstiled`) | **Dropped** | On Alpine dinit is only a user service manager, so a *system* dinit service makes no sense. On FeralOS dinit **is PID 1**, so upstream's `data/dinit/turnstiled` must ship to `/etc/dinit.d/turnstiled` (dinit scans `/etc/dinit.d` natively; service ordered `before: login.target`). |
| `turnstiled.initd` + `turnstiled.confd` | Dropped | No OpenRC on FeralOS. |
| `$pkgname-openrc` subpackage | Dropped | Same; `-doc` is the only subpackage. |
| runtime deps from tracedeps | `depends="linux-pam"` | `pam_turnstile.so` links libpam, and the `/etc/pam.d/turnstiled` stack needs `pam_limits`/`pam_rootok`/`pam_keyinit`/`pam_umask`/`pam_elogind`. |
| backend auto-detection | `-Ddefault_backend=dinit` pinned | The shipped `/etc/turnstile/turnstiled.conf` must read `backend = dinit` even if feature auto-detection ever changes. |
| `manage_rundir` default (`false`) | `-Dmanage_rundir=false` explicit | elogind owns `/run/user/<uid>`: `/etc/pam.d/turnstiled` runs `pam_elogind.so`, which creates the rundir and exports `XDG_RUNTIME_DIR`. turnstile managing the same path too would race elogind for ownership (create/remove treadmills, wrong permissions). |

Build flags: `-Db_lto=true -Ddinit=enabled -Ddefault_backend=dinit
-Dmanage_rundir=false`.

## Package contents

Installed by meson (`abuild-meson` → prefix `/usr`, sysconfdir `/etc`):

```
/usr/bin/turnstiled
/usr/lib/security/pam_turnstile.so
/etc/dinit.d/turnstiled                 # system service, upstream file kept
/etc/pam.d/turnstiled
/etc/turnstile/turnstiled.conf          # backend = dinit, manage_rundir = no
/etc/turnstile/backend/dinit.conf       # dinit backend: services_dir2=/etc/dinit.d/user
/usr/libexec/turnstile/dinit            # per-user dinit launcher
```

The PAM service file shipped upstream is exactly named `turnstiled`, which is
what `pam_turnstile.so turnstiled` and the turnstile polkit patch expect.

## Install

```sh
apk add turnstile
```

## Update procedure (Alpine bump or new upstream tag)

1. `./scripts/bump-upstream.sh turnstile` — bumps `_upstream`, resets `pkgrel`
   and refreshes the tarball sha512.
2. Re-fetch the Alpine edge/testing APKBUILD for the same upstream version and
   diff it against this one; mirror any new build flags or packaging changes
   (and consciously re-decide the dropped patch/subpackage list above).
3. Check the upstream meson options still contain `dinit`, `default_backend`
   and `manage_rundir`:
   `curl -sL https://raw.githubusercontent.com/chimera-linux/turnstile/v<ver>/meson_options.txt`.
4. Rebuild in docker `alpine:latest` (`abuild -Fr`) and verify the apk still
   contains the files above, with `backend = dinit` and `manage_rundir = no`
   inside `/etc/turnstile/turnstiled.conf`.
5. If Alpine itself moves to a newer session backend or FeralOS drops elogind,
   revisit `manage_rundir` and the `pam_elogind.so` line together.

## Version scheme

`pkgver=989.<upstream>`: the 989 major component always outranks any Alpine
version field-by-field (apk numeric compare), so this build always wins over
Alpine's `0.1.11-r2`. Bump the suffix in lockstep with upstream; `pkgrel`
resets to 0 on each upstream bump.
