# niri-user-dinit

dinit **user** services for the [niri](https://github.com/YaLTeR/niri) session
on FeralOS. No binaries, no Alpine counterpart — service files only.

## Purpose

Alpine's `niri` package ships `/usr/bin/niri-session`. When a user dinit
instance is running, `niri-session` starts the session through it:

```sh
dinitctl --user start niri
```

so niri is supervised as a real dinit service and `niri-shutdown` runs when it
exits. This package provides the two service files that make that work.

| File | Installed as | Role |
|------|--------------|------|
| `niri` | `/etc/dinit.d/user/niri` | `type = process`, `command = niri --session`, `restart = false`, `working-dir = $HOME`; `depends-on = dbus.user`, `after`/`chain-to = niri-shutdown`, `options: always-chain` |
| `niri-shutdown` | `/etc/dinit.d/user/niri-shutdown` | `type = scripted`; clears session env (`WAYLAND_DISPLAY`, `XDG_SESSION_TYPE`, `XDG_CURRENT_DESKTOP`, `XDG_SESSION_DESKTOP`, `NIRI_SOCKET`) |

Adapted from upstream niri v25.11 `resources/dinit/{niri,niri-shutdown}` with two
deviations:

- `depends-on = dbus.user` — FeralOS service name (`dbus-user-dinit`); upstream
  uses `dbus`, which does not exist here.
- `niri-shutdown` also clears `XDG_SESSION_DESKTOP`.

The service **must** be named `niri`: `niri-session` hardcodes both
`dinitctl --user start niri` and `dinitctl --user is-started niri`.

## The login-shell trick

`niri-session` re-execs itself through **bash** before it ever reaches the dinit
branch when the login shell looks valid:

```sh
if [ -n "$SHELL" ] &&
   grep -q "$SHELL" /etc/shells &&
   ! (echo "$SHELL" | grep -q "false") &&
   ! (echo "$SHELL" | grep -q "nologin"); then
    exec bash -c "exec -l '$SHELL' -c '$0 -l $*'"
fi
```

greetd always sets `SHELL` for the session. On Alpine `/bin/ash` **is** listed
in `/etc/shells`, so the default shell would trigger the bash re-exec — bash
would then run `niri-session -l` without a user dinit instance, the dinit branch
would fail its `pgrep -u $uid dinit` check, and the session would not be
supervised by dinit.

Fix: this package creates

```
/usr/libexec/feralos/login-shell -> /bin/ash
```

a fully functional shell at a path deliberately **not** listed in
`/etc/shells`. Pointing `SHELL` at it makes the check fail, so `niri-session`
skips the bash re-exec and continues straight to `dinitctl --user start niri`.

## Install / update

```sh
apk add niri-user-dinit          # pulls niri + dinit (and dbus-user-dinit at runtime)
```

Build / rehearse locally (docker `alpine:latest`):

```sh
abuild -Fr                       # checksums are embedded in the APKBUILD
tar -tzf ~/packages/niri-user-dinit/x86_64/niri-user-dinit-*.apk
```

Update procedure:

1. If upstream niri bumps its `resources/dinit/*`, refresh the two service
   files here (keep `dbus.user` as the dependency) and update `sha512sums`.
2. Bump `pkgver` (989 series) / `pkgrel`; `abuild -Fr`; verify the apk contains
   `/etc/dinit.d/user/niri`, `/etc/dinit.d/user/niri-shutdown` and
   `/usr/libexec/feralos/login-shell`.
3. Syntax check: `dinit-check -d /etc/dinit.d/user niri` (relative-command
   warnings are expected, matching upstream).
