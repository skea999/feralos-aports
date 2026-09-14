# STATUS

> **Update this file after EVERY completed step.** Latest entry on top.
> Plan: `PLAN.md`. Commit + push together with the step.

## Current

- **Step**: 2b ✅ COMPLETE — dinit-devd hook shipped (CI first-try green)
- **Next action**: Step 2c — `dinit-cryptdisks` hook: read upstream
  `early/scripts/cryptdisks.sh` arg semantics first, implement over
  /etc/crypttab + cryptsetup, add to source/package(), CI verify.

## Log

### 2026-09-10 — repo reorganized: packages under src/ (URL normalized)
- `dinit-chimera/` → `src/dinit-chimera/` (git mv, history preserved)
- NEW RULE: `src/` contains ONLY package dirs — one dir per package, all its
  assets inside (hooks, sysctl, service files); root stays clean
- workflow glob `src/*/APKBUILD`; docs synced (PACKAGES/REPOSITORY/CI/README/PLAN)
- terminology fixed: "stable contract (mandatory)" (was "upstream contract")
- **Pages URL: REPODEST follows the package parent dir → src/ changed it**;
  FIXED via Collect-step normalization (site/src → site/feralos-aports):
  documented URL `.../feralos-aports/x86_64/` is stable against future layout
  changes; client-test hardcode still matches (re-enable at 2d)

### 2026-09-10 — Step 2b COMPLETE (zero fixes)
- dinit-devd hook (eudev: /sbin/udevd, /bin/udevadm) installed at
  /usr/libexec/dinit-devd — upstream default meson path, no build flag needed
- sha512 pinned; CI smoke: installed + sh -n + settle executed live
- Run 34900455477: build/deploy success, client-test skipped (by design)
- Blocking gap CLOSED: with 2c+2d the suite becomes boot-functional

### 2026-09-10 — policy update: NO skipped gaps (user request) — new Steps 2e/2f/2g
- Console hook no longer skipped → **2e**: kbd loadkmap/setfont via /etc/conf.d/keymaps+consolefont (kbd-bkeymaps + font-terminus already in standardPackages)
- kdump → **2f**: kexec-tools 2.0.32 + makedumpfile 1.7.9 VERIFIED on Alpine community → add to dinit-chimera depends (early-kdump/try-kdump become functional)
- bless-boot → **2g**: NOT on Alpine (404 main+community) → package systemd-bless-boot standalone from systemd source; INERT on our UKI stack (no systemd-boot A/B) — ships ready for future; fallback DROPPED-FEATURES if build infeasible
- Device monitor: dummy stays (upstream default), real monitor = backlog
- PACKAGES.md divergence table updated; BOOT.md console row updated

### 2026-09-10 — Step 2a COMPLETE
- dinit-chimera-0.99.24-r0.apk: CI build green (meson direct — abuild-meson
  conflicts with -Dsbindir), smoke-install checks passed (boot service, mnt
  helper, init wrapper at /usr/libexec/dinit/init targeting /usr/bin/dinit,
  no bin-dir init leak)
- KEY FIX: -Dsbindir=bin — upstream hardcodes dinit_path=$prefix/sbindir/dinit,
  Alpine ships /usr/bin/dinit; wrapper relocation moved /usr/bin/init (sbindir=bin)
  instead of /usr/sbin/init
- Pages: feralos-aports/feralos-aports/x86_64/{dinit-chimera-0.99.24-r0.apk, APKINDEX.tar.gz} → 200
- Fix budget: 1/2 used

### 2026-09-10 — RULE 0 added + sd-tools dropped
- New rule 0: USE Alpine packages whenever they exist (checked on target branch
  v3.24 main+community); build ours only for missing/patched packages
- Verified: sd-tools 0.99.0-r3 in Alpine v3.24/community AND edge/community,
  provides cmd:sd-tmpfiles + cmd:sd-sysusers → our APKBUILD REMOVED from active
  tree (git history keeps it); Steps 1a/1b marked DONE-SUPERSEDED (kept as
  pipeline proof)
- client-test job disabled (`if: false`) until dinit-chimera lands (2a)
- docs/REPO-SETUP.md added: client setup on Alpine (key, repositories, real
  Pages URL layout, verification, origin policy, troubleshooting)
- PACKAGES.md: sd-tools section superseded; Alpine as-is table updated

### 2026-09-10 — Steps 1a + 1b COMPLETE
- `sd-tools-0.99.0-r0`: CI build (meson, acl=enabled, tests OK) + smoke-install
  verified (sd-tmpfiles, sd-sysusers present)
- **1b client-test GREEN**: fresh alpine:latest trusts ONLY feralos.pub →
  `apk add sd-tools=0.99.0-r0` from Pages WITHOUT --allow-untrusted → installed;
  provenance via apk policy. Signature chain cryptographically closed.
- Fixes (all distinct, within limits): no curl in alpine container (busybox
  wget); repo URL = repo ROOT (apk appends arch itself, /x86_64 doubled it);
  **version PIN =0.99.0-r0 required** — see next entry
- ⚠️ **Correction**: Alpine community HAS sd-tools 0.99.0-r3 (v3.23+; earlier
  "testing 404" was the wrong repo). We KEEP ours: self-contained repo + our-key
  signing. Client/installer MUST pin `=0.99.0-r0` (or our repo must be preferred)
  else apk resolves the newer Alpine package and bypasses our signature.
- Workflow: client-test job added (build → deploy → client-test chain)

### 2026-09-10 — DROPPED-FEATURES.md registry added

### 2026-09-14 — Step 1a DONE: CI green, Pages serving repo
- run 34789690767: build success + deploy success (6 attempts, see fixes below)
- sha512 sd-tools 0.99.0: f82471a33f204766977c24a56c78ad41a295cb7b7c8190bdad4d40c45db67677c3bb2f71222fc02ca1c42653bc60b2cf742b0114b5bfc2d9efdfc238c866c52f
- fixes landed: pub key derived via openssl (abuild-sign -e requires .pub),
  sha512sums entry needs "hash␣␣filename" format, abuild -Fr (autoinstall deps),
  `apk update` before abuild (apk-tools 3 resolves from cache only),
  checkdepends="bash" (test-sysusers.sh shebang → exit 127)
- test-sysusers 2/2 note: tmpfiles OK; sysusers OK after bash
- repo URL on Pages: https://skea999.github.io/feralos-aports/feralos-aports/x86_64/
  (REPODEST dir = source repo name, NOT v3.24/main — update installer docs/usage)
- APKINDEX.tar.gz + sd-tools-0.99.0-r0.apk both HTTP 200

### 2026-09-10 — DROPPED-FEATURES.md registry added
- Any dropped feature (rule 6) now requires an entry in docs/DROPPED-FEATURES.md:
  feature, reason, re-enable command, retry condition
- Registry pre-populated with policy-enabled features (sd-tools acl, tests)

### 2026-09-10 — rules clarified: optional pkgs mandatory, features best-effort, mkinitfs untested
- RULE 5 split: optional PACKAGES all mandatory (acl-dev etc. in makedepends);
  optional FEATURES best-effort — droppable only if build breaks AND boot
  doesn't need them (drop documented in STATUS)
- RULE 7 (ex-6) reworded: mkinitfs NOT tested by us — packages stay neutral,
  verified facts documented (Step 5 notes) for anyone picking it up
- Step 5 DoD back to booster-only boot; mkinitfs moved to a documentation
  subsection (init= support, idempotent handoff, cryptsetup feature note)
- PACKAGES.md sd-tools comment updated

### 2026-09-10 — policy: all optional features ON + mkinitfs compat in plan
- RULE 5 added: all optional deps/features ENABLED (sd-tools `-Dacl=enabled`,
  feature option — previous `-Dacl=true` was wrong syntax)
- RULE 6 added: packages initramfs-agnostic (no booster-specific deps)
- Step 5 extended: boot test with BOTH generators — mkinitfs `init=` support
  SOURCE-VERIFIED (`initramfs-init.in`: myopts init/init_args, exec switch_root
  "$KOPT_init", recovery shell if missing); pseudo-fs handoff idempotent;
  mkinitfs needs `cryptsetup` feature in conf for LUKS parity
- PLAN.md: Progress-at-a-glance table; Steps 0 + 3a marked DONE with evidence

### 2026-09-10 — Steps 1/2 split after upstream fact-finding
- Step 1 → **1a** (build) + **1b** (client-side signature test, closes old 3b)
- Step 2 → **2a** (build + init relocation) / **2b** (dinit-devd) / **2c**
  (dinit-cryptdisks) / **2d** (sysctl + final)
- Facts resolved (all upstream-verified):
  - sd-tools: only tag v0.99.0; C/gnu11; deps libcap (required) + libacl
    (option); NOT packaged on Alpine (testing 404)
  - dinit-chimera: init wrapper installed by meson to **/usr/sbin/init**
    (early/scripts/meson.build) → package() relocates to
    /usr/libexec/dinit/init (openrc coexistence)
  - NO scdoc needed (single pre-rendered manpage early-modules.target.8)
  - eudev paths: udevd = /sbin/udevd, udevadm = /bin/udevadm
    (eudev APKBUILD: --sbindir=/sbin --bindir=/bin; Alpine NOT usr-merged)
- PACKAGES.md drafts updated with resolved facts (no open TODOs left on 1a/2a)

### 2026-09-10 — Step 3a COMPLETE
- Secrets `ABUILD_PRIVKEY` + `ABUILD_KEYNAME=feralos` set as Repository secrets
  (were initially in github-pages environment → build job couldn't see them)
- Smoke test bug fixed: abuild-sign embeds signature into the file, temp removed
  — old `ls .SIGN*` assertion could never pass; new check = signed file differs
- Run `054869f` success with real key; run `90968af` (docs/CI.md) success
- `feralos.pub` on Pages MATCHES `~/.abuild/feralos.rsa.pub` (diff verified)
- Docs: `docs/CI.md` — pipeline, secrets, GitHub management, rotation

### 2026-09-10 — reordered: Step 3a (signing) pulled before Step 1
- Rationale: validate risky infra (secrets/keys/Pages) early; Step 1 then lands
  directly into a working publish pipeline
- PLAN.md: Step 3 split into 3a (now) + 3b (end-to-end with sd-tools)
- Workflow: added abuild-sign smoke test

### 2026-09-10 — Step 0 COMPLETE
- Run #3 (`fcc6be0`): build ✅ deploy ✅ — repo skeleton verified end-to-end
- Pages live: https://skea999.github.io/feralos-aports/ (placeholder README.txt;
  404 on root = no index.html, harmless for apk)
- DoD met: workflow exists, pushes clean, CI green

### 2026-09-10 — CI fix: empty-repo robustness
- First CI run failed as expected (no APKBUILDs yet): `*/APKBUILD` glob stayed
  literal → `cd *` error. Fixed with POSIX guard (`[ -e "$d" ] || continue`),
  "skipped" message on empty repo, signing-key fallback (`abuild-keygen -a -n`
  until secrets land in Step 3), Collect-site guard for empty ~/packages

### 2026-09-10 — repo bootstrapped
- Documentation moved in from installer repo, split by competence
  (packaging docs here; system docs BOOT/TROUBLESHOOTING stay in installer
  `docs/dinit/`)
- PLAN.md created (8 steps, checkbox-driven)
- No APKBUILDs yet — Step 0 not complete

## Blockers

- none
