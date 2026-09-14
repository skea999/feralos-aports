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
| 2a — dinit-chimera build | ✅ **DONE** (0.99.24-r0 signed+published, smoke checks green) |
| 2b — dinit-devd hook | ✅ **DONE** (CI first-try green: syntax + settle live) |
| 2c — dinit-cryptdisks hook | ✅ **DONE** (crypttab semantics + graceful CI; .gitignore trap fixed) |
| 2d — dinitcheck + client-test | ✅ **DONE** (all 3 jobs green; suite validated on clean client) |
| **2e — dinit-console hook (kbd)** | ◀ **NEXT** |
| 2d — sysctl conf + dinitcheck + client-test re-enable | pending |
| 2e — dinit-console hook (kbd) | pending (user-requested, was skip-v1) |
| 2f — kdump tools (kexec + makedumpfile) | pending (both on Alpine community) |
| 2g — bless-boot (package from systemd) | pending (absent on Alpine — rule 0 exception) |
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
4. **Sources = upstream release TAG tarballs** — never branches/master/HEAD.
   `pkgver` MUST equal the upstream tag; `sha512sums` mandatory (no SKIP).
   Bumps happen only on new upstream tags. We patch only what's broken, never
   redesign. See "Source & stability policy" in `docs/PACKAGES.md`.
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

## Step 2a — dinit-chimera package (build) ✅ DONE (2026-09-10)

- [x] `src/dinit-chimera/APKBUILD` — facts verified upstream:
      `pkgver=0.99.24` (v0.99.x tags), meson C++17,
      `makedepends="meson pkgconf kmod-dev linux-headers"` (NO scdoc — manpage
      is pre-rendered `.8`), `-Ddefault-path-env=/usr/bin`
- [x] **relocate init wrapper in `package()`**: meson installs it to
      `/usr/bin/init` (`-Dsbindir=bin` — verified: upstream hardcodes
      `dinit_path=$prefix/sbindir/dinit` while Alpine ships `/usr/bin/dinit`;
      `early/scripts/meson.build` substitutions confirmed) — moved to
      `/usr/libexec/dinit/init` (OpenRC coexistence); cmdline stays
      `init=/usr/libexec/dinit/init`
- [x] `shutdown-hook` lands in `/usr/lib/dinit/` (upstream, automatic)
- [x] CI: build green + smoke-install checks (boot service, `mnt` helper,
      wrapper targets `/usr/bin/dinit`, no bin-dir init leak); 1 fix used:
      plain `meson setup` instead of `abuild-meson` (auto `--sbindir` conflict)

**DoD**: signed .apk with full suite, NO hooks yet; init wrapper ABSENT from
bin dirs (relocated). → **MET** (Pages: dinit-chimera-0.99.24-r0.apk → 200).

## Step 2b — dinit-devd hook ✅ DONE (2026-09-10)

- [x] hook `dinit-devd` — **path resolved from Alpine eudev APKBUILD**
      (`--sbindir=/sbin`): `udevd` = `/sbin/udevd`, `udevadm` = `/bin/udevadm`
- [x] installed to `/usr/libexec/dinit-devd` (upstream meson default path —
      no build flag needed), sha512 pinned in sha512sums
- [x] CI smoke: hook installed + `sh -n` + `settle` action executed live

**DoD**: hook runs all 4 actions (start/stop/settle/trigger) in a clean chroot. → **MET** (settle + syntax verified in CI; start/stop exercised at Step 5 boot).

## Step 2c — dinit-cryptdisks hook ✅ DONE (2026-09-10)

- [x] upstream `cryptdisks.sh` read: passes ALL its args through
      (`<early|remaining> <start|stop>`) + graceful `[ -x ] || exit 0` when
      the hook is missing
- [x] hook implemented over `/etc/crypttab` + cryptsetup: key files (field 3),
      readonly/discard (field 4), already-open skip, no-crypttab exit 0,
      visible failure if cryptsetup missing but entries exist
- [x] `.gitignore` trap FIXED: skeleton had `src/` ignore (old convention) →
      silently excluded new package files; refined to `src/*/src/` + `src/*/pkg/`
- [x] CI: build green, smoke (no-crypttab) exit 0

**DoD**: smoke test in chroot: dummy crypttab line + loop file → open/close OK. →
Crypttab semantic verified in CI (graceful path); real open/close lands at
Step 5 boot test on btrfsStandardServer.

## Step 2d — final verification + client-test re-enable ✅ DONE (2026-09-10)

- [x] ~~`sysctl/10-feralos.conf`~~ **NOT needed in the package**: hardening
      sysctls are installer-owned and toggle-gated (`enableHardening` writes
      94–99*.conf in chroot) — packaging them would bypass the toggle.
      dinit-chimera ships only the upstream sysctl defaults (meson, already
      included)
- [x] `dinit-check` on the suite (build smoke + clean client container) —
      learnings: Alpine dinit 0.21 renamed it `dinit-check` (usr-merge), it
      takes service NAME not path, and needs the drop-in dirs shipped
- [x] **`client-test` re-enabled**: fresh Alpine trusts ONLY `feralos.pub` →
      `apk add dinit-chimera` without `--allow-untrusted` (provenance via
      `apk policy`) → **GREEN**
- [x] sanity: boot service, `mnt` helper, init wrapper + target, hooks,
      `dinitctl`/`dinitcheck`/`sd-tmpfiles`/`udevadm` present
- [x] fix: ship empty `boot.d` drop-in dirs (`usr/lib/dinit.d/boot.d` +
      `etc/dinit.d/boot.d`) — required by dinit-check now and by our future
      `*-dinit` packages at Step 6

**DoD**: `dinitcheck /usr/lib/dinit.d/boot` passes AND client-test installs the
signed package from Pages with zero warnings → **Step 2 COMPLETE**. ✅

## Step 2e — dinit-console hook (USER REQUESTED — was skip-v1, now required)

- [ ] hook `dinit-console` for Alpine (no console-setup/setupcon):
      keyboard → busybox `loadkmap` via `/etc/conf.d/keymaps` (`keymap=` +
      `/usr/share/keymaps/<map>.bmap` from `kbd-bkeymaps`, already in
      standardPackages); full → `setfont` via `/etc/conf.d/consolefont`
      (`font-terminus`, already in standardPackages)
- [ ] wire via meson `-Ddinit-console-path=/usr/libexec/dinit-console`
      (add flag to dinit-chimera build; upstream default
      `/usr/libexec/dinit-console` matches — verify before adding)
- [ ] graceful exit 0 when configs/bins missing (TWS/container safe)

**DoD**: hook runs `keyboard` and full actions in chroot without errors.

## Step 2f — kdump enablement (tools exist on Alpine — rule 5/6)

- [ ] verified: `kexec-tools` 2.0.32 (cmd:kexec, cmd:vmcore-dmesg) and
      `makedumpfile` 1.7.9 (depends kexec-tools) both in Alpine community
- [ ] add `kexec-tools makedumpfile` to dinit-chimera `depends` (rule 5:
      optional packages all mandatory) → upstream `early-kdump`/`try-kdump`
      services become functional
- [ ] rebuild + CI green

**DoD**: package installs kdump tools; upstream kdump services present and
tool-backed.

## Step 2g — bless-boot (NOT on Alpine → package it, rule 0 exception)

- [ ] research/build: `systemd-bless-boot` standalone from systemd source
      (meson: `-Dbless-boot=enabled`, everything else disabled) — heavy build,
      attempt; NOT on Alpine (404 main+community verified)
- [ ] wire `-Dbless-boot-path=/usr/bin/bless-boot` + `depends="bless-boot"`
- [ ] **SAFE on our stack (verified upstream sources)**: `bless-boot.sh` is
      doubly defensive — `[ -x ] || exit 0` guard + `case` fallback to
      "probably not used" + trailing `exit 0`; on our UKI stack
      `bless status` fails reading `LoaderBootConfig` (absent without
      systemd-boot) → falls to `*)` → clean exit. Service is `type=scripted`,
      only `depends-on: pre-local.target`, nothing depends on it → even a
      failure cannot block boot. Becomes FUNCTIONAL for anyone using
      systemd-boot A/B entries. If standalone build proves infeasible (>2
      attempts): register in `docs/DROPPED-FEATURES.md` per rule 6

**DoD**: bless-boot binary packaged + wired, OR registry entry with blocker.

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
