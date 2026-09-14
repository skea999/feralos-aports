# Development Plan — feralos-aports

> **Autonomous execution plan.** Work top-to-bottom, one step at a time.
> After EVERY step: tick the checkbox, update `STATUS.md`, commit + push.
> Full context: `docs/` in this repo. Installer-side plan:
> skeaAlpineInstaller `docs/dinit/PLAN.md`.

## Progress at a glance

| Step | State |
|------|-------|
| 0 — skeleton | ✅ **DONE** (CI green, Pages live) |
| 3a — signing infra | ✅ **DONE** (real key verified, `feralos.pub` published + matched) |
| 1a/1b — sd-tools | ⚠️ **DONE → SUPERSEDED** (Alpine community ships sd-tools 0.99.0-r3 — rule 0: use Alpine's; our package removed; work kept as pipeline proof) |
| **2a — dinit-chimera build** | ◀ **NEXT** (NOT in Alpine — ours is required) |
| 2b–2d — dinit-chimera (devd / cryptdisks / sysctl) | pending |
| 4 — getty-dinit | pending (NOT in Alpine) |
| 5 — boot test QEMU (booster) | pending |
| 6 — system services | pending (not in Alpine as -dinit variants) |
| 7 — desktop | pending (turnstile: only edge/testing → ours) |
| 8 — release v0.1.0 | pending |

## Rules

0. **Use Alpine packages whenever they exist.** Before creating ANY APKBUILD,
   check Alpine repos of the target branch (`v3.24` main + community; edge as
   signal). We build ONLY packages that: don't exist in Alpine, or need
   FeralOS-specific patches (e.g. polkit + `turnstile.patch`). Example:
   sd-tools was dropped — Alpine community ships 0.99.0-r3 with exactly the
   binaries we need.
1. One step = one commit = one push. Never batch steps.
2. Every step has a **DoD** (definition of done) — no step is done until DoD is met.
3. If blocked >2 attempts on the same error: stop, write blocker in `STATUS.md`,
   push, report back. Do not improvise architecture changes.
4. Sources point to upstream tarballs — we patch only what's broken, never redesign.
5. **Optional PACKAGES: ALL of them, mandatory.** Every optional dependency
   goes into `makedepends` unconditionally and gets compiled in.
6. **Optional FEATURES: enabled best-effort.** Try them all; a feature may be
   DROPPED only if the build fails for any reason AND it is not strictly
   necessary for boot — drop must be documented in `STATUS.md` AND registered
   in `docs/DROPPED-FEATURES.md` (feature, reason, re-enable command, retry
   condition) so we can work on it in the future.
7. **Initramfs-agnostic packages**: no booster-specific deps anywhere. mkinitfs
   is NOT tested by us — we keep packages compatible and document the verified
   facts so anyone else can pick it up (see Step 5 notes).

## Step 0 — Repo skeleton ✅ DONE (2026-09-10)

- [x] `.gitignore` (sources/, packages/, *.apk, keys)
- [x] `.github/workflows/build.yml` (empty-repo robust, POSIX guards)
- [x] commit + push

**DoD**: CI workflow exists (even if failing until APKBUILDs land); repo pushes clean. → **MET**: runs green (build skipped pre-packages), Pages live.

## Step 1a — sd-tools package (build) ✅ DONE (2026-09-10) — ⚠️ SUPERSEDED by rule 0

> Alpine community ships `sd-tools 0.99.0-r3` (v3.24 + edge) with
> `cmd:sd-tmpfiles` + `cmd:sd-sysusers` → we USE Alpine's. Our package was
> removed from the repo (history preserved). The 1a/1b work below remains
> as PROOF the pipeline works end-to-end (build→sign→publish→client verify).

- [x] `sd-tools/APKBUILD` — facts verified upstream:
      `pkgver=0.99.0` (only tag), C/gnu11 meson,
      `makedepends="meson libcap-dev acl-dev linux-headers"`,
      `-Dacl=enabled` (feature option — optional PACKAGE acl-dev mandatory
      per rule 5; feature itself best-effort per rule 6),
      `-Dtests=true` (default, explicit), `check()` via meson test
- [x] CI: build green + smoke-install (tests OK, binaries verified)
- [x] CI hardening learned: `apk update` before abuild (apk-tools 3),
      `abuild -Fr`, checksums format `hash␣␣filename`, pub key derived for
      abuild-sign, `checkdepends="bash"`

**DoD**: signed .apk in CI containing `/usr/bin/sd-tmpfiles` + `/usr/bin/sd-sysusers`. → **MET**.

## Step 1b — Publish end-to-end (closes old 3b) ✅ DONE (2026-09-10) — ⚠️ SUPERSEDED (see 1a)

- [x] CI publishes signed `APKINDEX.tar.gz` + sd-tools apk to Pages
      (real path: `<pages>/feralos-aports/x86_64/` — REPODEST = repo name)
- [x] **client test**: fresh alpine:latest container trusting ONLY
      `/etc/apk/keys/feralos.rsa.pub` → `apk add sd-tools=0.99.0-r0`
      **without** `--allow-untrusted` → installed, provenance via apk policy

**DoD**: cryptographic signature verified client-side (`UNTRUSTED` = fail). → **MET**.

> ⚠️ **Correction**: Alpine community HAS sd-tools 0.99.0-r3 (v3.23+; earlier
> "testing 404" was the wrong repo check). We keep OUR package (self-contained
> repo + our-key signing) — clients MUST pin `=0.99.0-r0` or our repo must be
> preferred, else apk resolves the newer Alpine build and bypasses our signature.

## Step 2a — dinit-chimera package (build)

- [ ] `dinit-chimera/APKBUILD` — **facts verified upstream**:
      `pkgver=0.99.24` (v0.99.x tags), meson C++17,
      `makedepends="meson kmod-dev linux-headers"` (NO scdoc — manpage is
      pre-rendered `.8`), `-Ddefault-path-env=/usr/bin`
- [ ] **relocate init wrapper in `package()`**: meson installs it to
      `/usr/sbin/init` (verified: `early/scripts/meson.build` configure_file
      with `@DINIT_PATH@`/`@DINIT_DEVD_PATH@`/etc. substitutions) — move to
      `/usr/libexec/dinit/init` to avoid conflict with openrc/busybox init
      (coexistence rule); cmdline stays `init=/usr/libexec/dinit/init`
- [ ] `shutdown-hook` lands in `/usr/lib/dinit/` (upstream, automatic)
- [ ] CI: build green + content check (52 services, `early/scripts/` 35+1,
      `early/helpers/` 12 binaries + `mnt-service` symlink, init wrapper)

**DoD**: signed .apk with full suite, NO hooks yet; `/usr/sbin/init` ABSENT from
the package (relocated).

## Step 2b — dinit-devd hook

- [ ] hook `dinit-devd` — **path resolved from Alpine eudev APKBUILD**
      (`--sbindir=/sbin`): `udevd` = `/sbin/udevd`, `udevadm` = `/bin/udevadm`
- [ ] wire via meson `-Ddinit-devd-path=/usr/libexec/dinit-devd`

**DoD**: hook runs all 4 actions (start/stop/settle/trigger) in a clean chroot.

## Step 2c — dinit-cryptdisks hook

- [ ] read upstream `early/scripts/cryptdisks.sh` first (arg semantics:
      `early|remaining` + `start|stop`)
- [ ] implement hook over `/etc/crypttab` + cryptsetup; wire
      `-Ddinit-cryptdisks-path=/usr/libexec/dinit-cryptdisks`

**DoD**: smoke test in chroot: dummy crypttab line + loop file → open/close OK.

## Step 2d — sysctl conf + final verification

- [ ] `sysctl/10-feralos.conf` (port from installer hardening feature)
- [ ] final: clean chroot → install → `dinitcheck /usr/lib/dinit.d/boot` passes

**DoD**: full suite installable + syntax-clean; package complete without
workarounds beyond the 2 hooks + init relocation.

## Step 3a — Signing + publish infra ✅ DONE (2026-09-10)

- [x] key pair generated locally: `~/.abuild/feralos.rsa` + `.rsa.pub` (openssl)
- [x] `feralos.pub` committed at repo root
- [x] workflow: `abuild-sign` smoke test (signed file must differ — signature is
      embedded, temp removed)
- [x] **user action done**: GitHub Repository secrets `ABUILD_PRIVKEY` +
      `ABUILD_KEYNAME=feralos`; retrigger → green with real key
- [x] Pages live: `feralos.pub` served and byte-identical to local pub

**DoD**: CI green using the REAL committed key (not ephemeral); pub key served. → **MET**.

## Step 3b — Published repo end-to-end (folded into Step 1b)

- [ ] CI signs sd-tools + `APKINDEX.tar.gz` with the real key
- [ ] published URL fetchable: `curl <pages-url>/v3.24/main/x86_64/APKINDEX.tar.gz`

**DoD**: from ANY Alpine chroot: add key + repo → `apk add sd-tools` works.

## Step 4 — getty-dinit (needed for boot test)

- [ ] `getty-dinit/APKBUILD`: `getty@` template service (agetty from util-linux)
      + enabled `getty@tty1` + `getty@ttyS0` instance for harness serial console
- [ ] service file pattern: `depends-on: login.target`, `runs-on-console`

**DoD**: package builds; service file validates with `dinitcheck`.

## Step 5 — Boot test QEMU, booster (with installer repo)

- [ ] clean Alpine chroot: install our repo packages + `init=/usr/libexec/dinit/init`
      in `/etc/kernel/cmdline` (regenerate UKI)
- [ ] boot test: serial console reaches getty login prompt
- [ ] packages audited: NO booster-specific deps anywhere (rule 7) —
      dinit-chimera `depends=` is booster/mkinitfs neutral
- [ ] iterate: fix issues ONLY in our hooks/packages; upstream bugs → note in
      `STATUS.md`, never patch upstream scripts
- [ ] coordinate with installer repo: harness fixture
      `btrfs_standard_dinit.yaml` (installer PLAN Phase 2)

**DoD**: boots to login prompt under Dinit (booster); full early chain visible
in serial log.

### mkinitfs compatibility — documented, NOT tested by us

We keep the packages compatible so anyone else can run dinit on mkinitfs.
Source-verified facts (`initramfs-init.in`), ready to use:

- mkinitfs honors `init=`: `init`/`init_args` in `myopts`,
  `exec switch_root … "$KOPT_init"`, default `/sbin/init`, recovery shell if
  the binary is missing in the new root
- it mounts /proc /sys /dev /dev/pts /dev/shm and moves the early mounts before
  `switch_root` — dinit-chimera's `mnt prepare` is idempotent (`do_try`
  skips already-mounted), so the handoff is seamless
- LUKS parity: mkinitfs needs the `cryptsetup` **feature** enabled in
  `/etc/mkinitfs/mkinitfs.conf` (+ `cryptroot=` cmdline); installer Phase 5 may
  write that config when mkinitfs is chosen
- our packages carry zero booster deps — nothing prevents a mkinitfs boot today

Out of scope: actually boot-testing mkinitfs. Anyone picking this up starts
from the facts above.

## Step 6 — System services (`*-dinit`)

Order: dbus → sshd → chronyd → cronie → acpid → irqbalance → earlyoom → vector
(+vector-setup) → incusd → fwupd. Pattern in `docs/CONVERSION.md`.
Each: APKBUILD + service file → build → `dinitcheck` → enable via boot.d.

**DoD**: full FeralOS standardPackages service parity under Dinit (list from
installer `internal_rules.yaml` `services:` map).

## Step 7 — Desktop packages

- [ ] `elogind-dinit` / `seatd-dinit` (exclusive)
- [ ] `greetd-dinit`, `cosmic-greeter-dinit`, `sddm-dinit`
- [ ] `turnstile` (APKBUILD draft in `docs/PACKAGES.md`; Alpine edge APKBUILD as base)
- [ ] `polkit` (Alpine 127-r2 APKBUILD copy + `turnstile.patch` from Chimera cports)

**DoD**: all DE services build + validate; polkit patched variant installs.

## Step 8 — Release v0.1.0

- [ ] tag `v0.1.0` → CI publishes indexed tree under `v3.24/main`
- [ ] notify installer repo (STATUS.md cross-ref) → installer Phase 5 begins

---

## Backlog (post-v0.1.0)

- real udev device monitor (replace upstream `dinit-chimera-device-none` dummy)
- OpenRC removal decision (with installer repo)
- LLVM toolchain experiment (see `docs/TOOLCHAIN.md` — closed for now)
- **Self-hosted port**: Gitea + native Alpine runner (act_runner) + gitea-pages-server —
  full proposal and migration checklist in `docs/SELF-HOSTING.md`
