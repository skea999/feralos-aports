# polkit

Privilege delegation daemon. FeralOS needs a patched build so that processes
registered through **turnstile** (`turnstiled` shared session, no seat) still
count as *local/active* for polkit `allow_active` rules.

- Base: Alpine **community/polkit 127-r2** — copied integrally (APKBUILD,
  `alpine-polkit.pam`, `polkit.initd`, `polkit-common.pre-install`,
  `polkit-common.pre-upgrade`).
- Upstream source: https://github.com/polkit-org/polkit tag `127`.
- Version: `_upstream=127`, `pkgver=989.127`, `pkgrel=0` (989 override series,
  see below).

## Both variants are kept, but only one is patched in effect

Alpine's APKBUILD builds polkit **twice** from one source tree:

| Build | `-Dsession_tracking=` | Session monitor compiled | Package |
|-------|-----------------------|--------------------------|---------|
| ConsoleKit | `ConsoleKit` | `polkitbackendsessionmonitor.c` | `polkit` (base) |
| elogind | `elogind` | `polkitbackendsessionmonitor-systemd.c` | `polkit-elogind` subpackage |

`patches/turnstile.patch` modifies
`src/polkitbackend/polkitbackendsessionmonitor-systemd.c`, which meson only
compiles when `enable_logind` is set (`if enable_logind` in
`src/polkitbackend/meson.build`). In the ConsoleKit build the file is never
compiled, so **the patch is only effective in the elogind variant** — therefore
the installer uses `polkit-elogind` (plus `polkit-elogind-dinit` for the dinit
service). The patch applies cleanly to the shared source tree for both builds;
it is simply dead code in the ConsoleKit one.

## Patch series (one patch, deliberately)

- `patches/turnstile.patch` — from Chimera cports `main/polkit/patches/
  turnstile.patch`, **commit `8d98aa42`** (q66, 2023-07-02, "ensure
  turnstile-session processes fall back to display check"). Semantics: if the
  process's session service is `turnstiled`, do **not** resolve that shared
  session; fall back to `sd_uid_get_display`, so turnstile-registered user
  services (DMS power menu, etc.) resolve as the graphical session and
  `allow_active` rules match.

Other Chimera cports polkit patches are intentionally **not** taken:

| Patch | Why excluded |
|-------|--------------|
| `dbus-activation.patch` | Rewrites D-Bus activation to `dinitctl start polkitd` — FeralOS ships its own polkit dinit service (`polkit-dinit`/`polkit-elogind-dinit`); unrelated to turnstile session semantics. |
| `readiness.patch` | dinit readiness (`POLKITD_READY_FD`) — same reason; our service files handle ordering. |
| `disable-sd-pidfd.patch` | Disables `HAVE_PIDFD_OPEN` due to broken GNOME auth in Chimera — unrelated to turnstile and security-relevant, so we keep pidfd. |

## Update procedure (Alpine bump)

1. Bump `_upstream` to the new polkit version, reset `pkgrel=0`, refresh the
   tarball sha512.
2. **Refresh the base diff**: download the new Alpine `community/polkit/
   APKBUILD` (+ `alpine-polkit.pam`, `polkit.initd`, pre-install/pre-upgrade)
   and re-apply our two deviations: `patches/turnstile.patch` in `source` and
   the `_upstream`/`pkgver` override header. Keep everything else identical.
3. **Re-verify the patch applies**: run `abuild -Fr` and check the build log
   contains `patching file src/polkitbackend/polkitbackendsessionmonitor-systemd.c`.
   If the hunk context moved, rebase the patch against the new source (keep the
   original commit header `8d98aa42` and note the rebase in the APKBUILD
   header).
4. Rebuild both variants in docker `alpine:latest` and smoke-install
   `polkit-elogind` + `polkit-elogind-dinit`.
5. Re-check the non-elogind variant still builds: `polkit` base is required by
   `polkit-dinit` and `quickshell`, exactly as in Alpine.

## Version scheme

`pkgver=989.<upstream>`: the 989 major component always outranks any Alpine
version field-by-field (apk numeric compare), so our patched build always wins
over Alpine's `127-r2` (which also made the patch dead weight at equal
`pkgver`). Bump the suffix in lockstep with Alpine; `pkgrel` resets to 0 on
each upstream bump.
