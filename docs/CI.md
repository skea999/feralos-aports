# CI — How the build pipeline and secrets work

> Workflow: `.github/workflows/build.yml`
> Hosted on: GitHub Actions, published to GitHub Pages.

## Pipeline overview

```
push / PR / manual (workflow_dispatch) on main
        │
        ▼
┌─────────────────────── build job (container: alpine:latest) ─────────────────┐
│ 1. Install toolchain      alpine-sdk + git (abuild, apk, abuild-sign)        │
│ 2. Checkout               repo content (APKBUILDs, feralos.pub, docs)        │
│ 3. Key setup              real key from secrets, or ephemeral fallback       │
│ 4. Signing smoke test     abuild-sign must modify a test file                │
│ 5. Build all packages     one abuild -F per src/*/APKBUILD dir             │
│ 6. Index repositories     apk index + abuild-sign → APKINDEX.tar.gz          │
│ 7. Collect site           feralos.pub + ~/packages tree → site/              │
│ 8. Upload artifact        site/ → GitHub Pages artifact                      │
└──────────────────────────────────────────────────────────────────────────────┘
        │ only on push to main
        ▼
┌─────────────────────── deploy job (ubuntu-latest) ───────────────────────────┐
│ actions/deploy-pages      publishes the artifact to                          │
│                           https://skea999.github.io/feralos-aports/          │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Step details

**3. Key setup** — two paths:

- **Secrets present**: writes `ABUILD_PRIVKEY` to `~/.abuild/$ABUILD_KEYNAME.rsa`
  and creates `~/.abuild/abuild.conf` pointing at it. This is the production path:
  packages and `APKINDEX.tar.gz` are signed with the key whose public half is
  committed as `feralos.pub`.
- **Secrets missing** (skeleton/testing): `abuild-keygen -a -n` generates an
  **ephemeral** in-runner key. Packages still build and get signed, but that key
  is destroyed with the runner — artifacts from these runs are for smoke-testing
  only and must never be trusted by clients.

**4. Signing smoke test** — `abuild-sign` embeds the signature INTO the file
(apk v2 format) and deletes its temp file. The test therefore signs a file and
asserts the file changed. Catches broken key setup before a 20-minute build.

**6. Index** — `apk index` concatenates package metadata into `APKINDEX.tar.gz`,
then `abuild-sign` signs it. Skipped while no packages exist.

**7–8. Publish layout**:

```
https://skea999.github.io/feralos-aports/
├── feralos.pub                              # clients → /etc/apk/keys/
└── <branch>/main/x86_64/
    ├── APKINDEX.tar.gz                      # signed
    └── *.apk                                # signed
```

## Secrets

### What exists

| Secret | Value | Purpose |
|--------|-------|---------|
| `ABUILD_PRIVKEY` | full PEM content of `~/.abuild/feralos.rsa` (including `-----BEGIN/END-----` lines) | the **private** signing key — signs every `.apk` and `APKINDEX.tar.gz` |
| `ABUILD_KEYNAME` | `feralos` | key **base name**; must match the committed public key file name `feralos.pub` (apk signatures embed this name) |

### Why the key NAME matters

A signed package carries `.SIGN.RSA.feralos.rsa.pub` — apk on the client looks
up that exact name in `/etc/apk/keys/`. Renaming the key means re-signing
everything and redistributing the new pub key. Keep it stable.

### Where they live (and where they DON'T)

- **Repository secrets** (`Settings → Secrets and variables → Actions → Secrets`)
  — ✅ this is where they must be. The `build` job reads them via `env:` and has
  no `environment:` declared, so it only sees repository secrets.
- **Environment secrets** (`Settings → Environments → github-pages`) — ❌ build
  secrets do NOT belong here. The `github-pages` environment exists only because
  `actions/deploy-pages` requires it on the `deploy` job; it needs no secrets
  (uses the automatic `GITHUB_TOKEN`).

### How GitHub manages them

- Stored **encrypted at rest** (sealed-box); decrypted only on the runner when a
  job references them, never sent to steps that don't request them.
- Values are **auto-masked** in run logs (replaced with `***`) when echoed
  verbatim. Caution: masking is exact-match on the secret value — treat all logs
  as potentially sensitive anyway; if a key ever leaks, **rotate immediately**
  (see below).
- **Fork pull requests do not receive secrets.** A PR from a fork runs the
  workflow without `ABUILD_PRIVKEY` → falls back to the ephemeral key. This is
  GitHub's anti-exfiltration design and it works in our favor.
- The private key is written inside the **ephemeral build container**, which is
  destroyed after the job. It never lands in the repo, the Pages site, or the
  published artifacts.
- Scope is repository-wide; there is no branch restriction on repository secrets
  (that would require environment protection rules — not needed here).

## Key lifecycle

### Generate (already done — local machine only)

```sh
mkdir -p ~/.abuild
openssl genrsa -out ~/.abuild/feralos.rsa 2048
openssl rsa -in ~/.abuild/feralos.rsa -pubout -out ~/.abuild/feralos.rsa.pub
chmod 600 ~/.abuild/feralos.rsa
```

The private key NEVER leaves the local machine except as a GitHub secret paste.
Only `feralos.rsa.pub` (copied to `feralos.pub` in the repo) is public.

### Rotate (if compromised or on policy)

1. Generate a new pair (commands above, new name recommended: `feralos-2027.rsa`)
2. Update both GitHub secrets (`ABUILD_PRIVKEY`, `ABUILD_KEYNAME`)
3. Replace `feralos.pub` in the repo → commit → CI republishes
4. Clients get the new key with the next installer release (installer copies it
   to `/etc/apk/keys/`)
5. Old packages remain verifiable only by whoever still has the old pub key —
   a rotation effectively requires re-publishing (bump all packages), which the
   CI does on the next run

## Local reproduction of the CI

```sh
apk add alpine-sdk git
# secrets equivalent:
mkdir -p ~/.abuild
cp /path/to/feralos.rsa ~/.abuild/feralos.rsa
printf 'PACKAGER="FeralOS <dev@feralos.org>"\nPACKAGER_PRIVKEY="$HOME/.abuild/feralos.rsa"\n' \
  > ~/.abuild/abuild.conf

cd sd-tools && abuild -F     # builds + signs with the real key
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Run uses ephemeral key (log: `abuild-keygen`) | secrets missing or saved as **environment** secrets | move to **Repository secrets** |
| `signing did not modify file` | key invalid/empty | re-check `ABUILD_PRIVKEY` paste (full PEM, no truncation) |
| `deploy` job fails | Pages not enabled | Settings → Pages → Source: **GitHub Actions** |
| `cd: can't cd to *` | no packages in repo (historical) | fixed by POSIX glob guard; packages arrive from Step 1 |
| client `UNTRUSTED signature` | pub key missing/mismatched on client | reinstall `feralos.rsa.pub` into `/etc/apk/keys/` |
