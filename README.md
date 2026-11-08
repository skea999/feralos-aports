# feralos-aports

FeralOS package repository — APKBUILD sources for the Dinit integration.

**Autonomous repo**: own `.git`, own releases. Nested in the FeralOS installer
checkout (`references/feralos-aports`, ignored by the outer repo).

## Start here

1. **`PLAN.md`** — the execution plan. Work top-to-bottom, one step per commit.
2. **`STATUS.md`** — current step, next action, blockers. Update after every step.
3. `docs/` — packaging documentation (APKBUILD drafts, upstream reference, CI).

System-side docs (boot flow, troubleshooting the installed system) live in the
installer repo: `docs/dinit/` on `developDinit`.

## Packages

**Rule 0: use Alpine packages whenever they exist.** We build only what Alpine
doesn't ship or what needs FeralOS patches.

**Alpine name conflicts — 989 override series.** When a FeralOS package shares
its name with an Alpine package (`sd-tools`, `turnstile`, `polkit`), `pkgver`
is `989.<upstream>` (dots only). The 989 major component always outranks any
Alpine version field-by-field (apk numeric compare), so our build is always
selected; the Alpine repo still serves transitive deps. Bump the suffix in
lockstep with upstream. Rationale comment lives in each conflicting APKBUILD.

| Package | Source | Phase |
|---------|--------|-------|
| `sd-tools` | **ours again (989.0.99.0-r0)** — rule 0 exception: Alpine's r3 segfaults at runtime (GCC use-after-scope in tmpfiles, [upstream #5](https://github.com/chimera-linux/sd-tools/issues/5)); we carry the static-storage patch; 989 override series always beats Alpine's `0.99.x` | 2 |
| `networking-dinit` | ours — `ifup -a` (nothing else brings eth0 up under dinit) | 2 |
| `feralos-keyring` | ours — key + repo definition | done |
| `dinit-chimera` | [chimera-linux/dinit-chimera](https://github.com/chimera-linux/dinit-chimera) | 2 |
| `getty-dinit` | ours (single `getty` template body; upstream ships none) | 4 |
| `*-dinit` services | ours — **Alpine/Artix model: ship the service file only, install ≠ enabled**; service names = Alpine initd names (chronyd, sshd, incusd...); enablement via `dinitctl --offline enable` from installer rules | 6 |
| `elogind-dinit` / `seatd-dinit`, DM services | ours | 7 |
| `turnstile` | [chimera-linux/turnstile](https://github.com/chimera-linux/turnstile) (989.0.1.11) | 7 |
| `polkit` (patched) | Alpine APKBUILD + Chimera `turnstile.patch` (989.127) | 7 |
| `cli11` | [CLIUtils/CLI11](https://github.com/CLIUtils/CLI11) (2.7.2) — quickshell build dep, absent in Alpine | desktop |
| `quickshell` | [outfoxxed/quickshell](https://quickshell.org/) (0.3.1) — QtQuick shell toolkit (DMS runtime dep); crash-handler dropped (cpptrace absent in Alpine) | desktop |
| `dms-shell` | [duxlabs-dev/dux-shell](https://github.com/duxlabs-dev/dux-shell) (1.6.2, tag `v1.6.2`) — Quickshell desktop shell, QML embedded in Go binary (+ `dank-qml-common` merged from tag `v1.6.0` in `prepare()`); musl native, replaces nix dms-shell | desktop |
| `matugen` | [InioX/matugen](https://github.com/InioX/matugen) (4.2.0) — Material You palette generator; dms-shell dynamic-theming backend (absent in Alpine) | desktop |
| `dbus-user-dinit` | ours — user dinit session bus (pipefd:3 readiness + `dinitctl setenv` bus address) | desktop |
| `pipewire-user-dinit` | ours — user dinit service for pipewire | desktop |
| `pipewire-pulse-user-dinit` | ours — user dinit service for pipewire-pulse (PulseAudio compat) | desktop |
| `wireplumber-user-dinit` | ours — user dinit service for wireplumber (session/policy manager) | desktop |
| `wayland-wait-user-dinit` | ours — user dinit gate: waits for any compositor wayland socket in `$XDG_RUNTIME_DIR` | desktop |
| `polkit-agent-user-dinit` | ours — user dinit service for polkit-gnome auth agent (distro-native build) | desktop |

## Source pinning policy

**Rule: every GitHub source pins to a TAG archive (`archive/refs/tags/...`), never a commit archive (`archive/<sha>...`). Release-asset URLs (`releases/download/...`) and non-GitHub URLs are handled at inventory time (see below). The sha512sum is the integrity guard; the tag is the version contract.**

- **Tags give version semantics + fail-loud.** Commit pins would keep old bytes forever — if upstream re-publishes a tag to fix a bug or CVE, the checksum FAILS, and that failure is the *signal* to review.
- **Checksum failure workflow** (tag re-published upstream and `abuild` now rejects the old sum):
  1. Fetch the new tag archive.
  2. Diff its content against the old archive (extract both, `diff -r` after normalizing the top dir — the only expected change is the directory name).
  3. If the diff is a legitimate fix: update `sha512sums`, bump `pkgrel`, note the ported fix in the commit message.
  4. If the diff is unexpected or hostile (unrequested changes, minified blobs): STOP, report, investigate upstream before shipping anything.
- **Full-sweep evidence pattern:** re-fetched sums that match a previous validated sum (and a top-dir-normalized diff of `rc 0`) prove a re-published tag carries identical bytes — the safe baseline for a revert or a re-pin.
- **Non-GitHub URLs** (Alpine mirrors, upstream hosts, GitLab): inventory them per APKBUILD. A versioned release artifact is fine; a moving target (`main`/`master`/HEAD) must be fixed to a pinned versioned artifact.
- **Our own repos** (`skea999/feralos`, `skea999/ursine`, `skea999/dms-window-buttons`): cut a tag for each source state used by a package (e.g. `dbus-audit-0.1.0` for `feralos-dbus-audit`) instead of pinning by commit.

Toolchain: **GCC** (Alpine default) — decision record: `docs/TOOLCHAIN.md`.

## Build (local)

```sh
apk add alpine-sdk git
abuild-keygen -a -n          # once
cd src/dinit-chimera && abuild -Fr
apk add --repository ~/packages/dinit-chimera/x86_64/ --allow-untrusted dinit-chimera
```

Client setup on an Alpine system (key + repositories + verification):
**`docs/REPO-SETUP.md`**.

## CI / Publishing

GitHub Actions (`.github/workflows/build.yml`): build on `alpine:latest`
(latest stable — matches installer's `branch: latest-stable`) →
`apk index` + `abuild-sign` → GitHub Pages.
Published layout: `feralos.pub` + `feralos-aports/x86_64/{APKINDEX.tar.gz,*.apk}`.

Secrets: `ABUILD_PRIVKEY`, `ABUILD_KEYNAME` — **Repository secrets** (NOT
environment secrets). Full explanation: `docs/CI.md`.

## Docs

- `docs/PLAN.md` / `docs/PACKAGES.md` / `docs/SERVICES.md` — plan, APKBUILD drafts, upstream reference
- `docs/CONVERSION.md` — OpenRC → Dinit service files (Phase 3+)
- `docs/REPOSITORY.md` / `docs/CI.md` — repo hosting, pipeline, secrets, rotation
- `docs/TOOLCHAIN.md` — GCC/aports decision record
- `docs/REPO-SETUP.md` — how to set up the package repository on an Alpine system
- `docs/SELF-HOSTING.md` — future port to self-hosted Gitea + native Alpine runner (proposal)
- D-Bus activation + boot-oneshot patterns: see `DBUS-ACTIVATION.md`.
