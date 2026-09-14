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

| Package | Source | Phase |
|---------|--------|-------|
| ~~`sd-tools`~~ | **Alpine community 0.99.0-r3** — use Alpine's (rule 0; ours removed) | — |
| `dinit-chimera` | [chimera-linux/dinit-chimera](https://github.com/chimera-linux/dinit-chimera) | 2 |
| `getty-dinit` | ours (`getty@` template, upstream ships none) | 4 |
| `*-dinit` services | ours (~10-line files, pattern in `docs/CONVERSION.md`) | 6 |
| `elogind-dinit` / `seatd-dinit`, DM services | ours | 7 |
| `turnstile` | [chimera-linux/turnstile](https://github.com/chimera-linux/turnstile) | 7 |
| `polkit` (patched) | Alpine APKBUILD + Chimera `turnstile.patch` | 7 |

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
Published layout: `feralos.pub` + `v3.24/main/x86_64/{APKINDEX.tar.gz,*.apk}`.

Secrets: `ABUILD_PRIVKEY`, `ABUILD_KEYNAME` — **Repository secrets** (NOT
environment secrets). Full explanation: `docs/CI.md`.

## Docs

- `docs/PLAN.md` / `docs/PACKAGES.md` / `docs/SERVICES.md` — plan, APKBUILD drafts, upstream reference
- `docs/CONVERSION.md` — OpenRC → Dinit service files (Phase 3+)
- `docs/REPOSITORY.md` / `docs/CI.md` — repo hosting, pipeline, secrets, rotation
- `docs/TOOLCHAIN.md` — GCC/aports decision record
- `docs/REPO-SETUP.md` — how to set up the package repository on an Alpine system
- `docs/SELF-HOSTING.md` — future port to self-hosted Gitea + native Alpine runner (proposal)
