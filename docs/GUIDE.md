# Service Generation & Update Guide

How the automatic generation of dinit services works, how to add/update/remove services, and how to keep them in sync with upstream.

## Architecture

```
scripts/services/<name>       ← MANIFEST: source of truth (one file per service)
                                   Empty/alpine-dep only = auto-generate from Alpine .initd
                                   Has overrides = use those values instead of defaults

scripts/fetch-alpine-openrc.sh ← extracts .initd files from Alpine aports (3.24-stable)
                                 to references/alpine-openrc/<pkg>/

scripts/generate-services.sh   ← reads manifests + .initd → generates src/<name>-dinit/
                                 (APKBUILD + service file per package)

src/<name>-dinit/              ← generated packages (committed, built by CI)
```

## The manifest file (`scripts/services/<name>`)

One file per service. Three possible states:

### 1. Auto-generated (no overrides)

```
alpine-dep: dbus
```

The generator reads the Alpine `.initd` and extracts `command=` + `command_args=` automatically. Everything else uses defaults (`type=process`, `restart=true`, `depends-on=local.target`).

### 2. With overrides

```
alpine-dep: busybox
command = /sbin/mdev -s
restart = false
```

The generator uses the Alpine `.initd` for anything NOT overridden, and the manifest lines for anything that IS overridden. Supported override fields:

| Field | Default (from .initd or fallback) | Override example |
|-------|-----------------------------------|------------------|
| `command` | extracted from `.initd` `command=` + `command_args=` | `/sbin/mdev -s` |
| `restart` | `true` | `false` (one-shot services) |
| `depends-on` | `local.target` | `network.target` |

### 3. Covered by dinit-chimera (tracked, not built)

```
alpine-dep: eudev
covered-by: dinit-chimera
```

The generator **skips** these (no package generated). They're tracked for completeness — the dinit-chimera early boot chain already handles them. This avoids conflicts (two services doing the same thing).

## Commands

### Generate all services

```sh
./scripts/generate-services.sh
```

Creates/updates `src/<name>-dinit/` for every manifest in `scripts/services/`. Idempotent — running twice produces the same result.

### Verify without writing

```sh
./scripts/generate-services.sh --check
```

Reports missing files or syntax errors without generating anything.

### Extract Alpine openrc files

```sh
./scripts/fetch-alpine-openrc.sh                 # all target packages from 3.24-stable
./scripts/fetch-alpine-openrc.sh dbus avahi      # specific packages only
APORTS_BRANCH=edge ./scripts/fetch-alpine-openrc.sh  # from edge
```

Output: `references/alpine-openrc/<pkg>/` (APKBUILD + `*.initd` + `*.confd`). Gitignored.

### Check for upstream tag updates

```sh
./scripts/bump-upstream.sh                       # dinit-chimera + turnstile
./scripts/bump-upstream.sh dinit-chimera         # single package
```

Compares current `pkgver` with latest upstream tag. If newer: updates `pkgver` + `sha512sums`. **Does not push** — review the diff, commit manually.

## How to add a new service

1. Create the manifest:
   ```sh
   echo "alpine-dep: mypackage" > scripts/services/mypackage
   ```
2. Run the generator:
   ```sh
   ./scripts/generate-services.sh
   ```
3. Verify the generated service file:
   ```sh
   cat src/mypackage-dinit/mypackage
   ```
4. If the command needs customization, add override lines to the manifest:
   ```
   alpine-dep: mypackage
   command = /usr/bin/mypackage --custom-flag
   restart = false
   ```
5. Re-run the generator (it applies the overrides).
6. Compute sha512sums (the generator does it), commit, push.

## How to modify an existing service

1. Edit `scripts/services/<name>` — add or change override lines.
2. Re-run `./scripts/generate-services.sh`.
3. The generated file in `src/<name>-dinit/` is updated.
4. Commit + push → CI rebuilds and republishes.

## How to remove a service

1. Delete `scripts/services/<name>`.
2. Delete `src/<name>-dinit/`.
3. Commit + push.

## How to update upstream packages (dinit-chimera, turnstile)

```sh
./scripts/bump-upstream.sh
```

Checks the latest upstream tag via GitHub API. If newer than current `pkgver`: updates `pkgver` + `sha512sums`. Review the diff, commit, push.

## How to update from Alpine stable changes

1. Re-extract Alpine openrc files (they may have new patches or config changes):
   ```sh
   ./scripts/fetch-alpine-openrc.sh
   ```
2. Re-generate all services (picks up new `.initd` content):
   ```sh
   ./scripts/generate-services.sh
   ```
3. Commit any changed files + push.

## CI pipeline

Every push to `main` triggers:

1. **build** — `abuild -Fr` per package (feralos-keyring first, then alphabetical), smoke-install (verifies files exist, hooks run, `dinit-check` passes), sign + index, collect site
2. **deploy** — publish to GitHub Pages
3. **client-test** — fresh Alpine container: trusts ONLY `feralos.pub`, installs ALL our packages via keyring flow (no `--allow-untrusted`), `dinit-check` boot+system, sanity binaries

See `docs/CI.md` for details.

## File structure reference

```
feralos-aports/
├── scripts/
│   ├── services/                # 44 manifests (one per service)
│   │   ├── acpid
│   │   ├── apparmor
│   │   ├── ...
│   │   └── xdg-document-portal
│   ├── fetch-alpine-openrc.sh   # extract .initd from Alpine aports
│   ├── generate-services.sh     # generate src/*-dinit from manifests
│   └── bump-upstream.sh         # check + bump upstream tags
├── src/
│   ├── dinit-chimera/           # complex package (APKBUILD + hooks + sysctl)
│   ├── getty-dinit/             # complex package (getty@ template)
│   ├── feralos-keyring/         # keyring package
│   ├── turnstile/               # (Phase 7, planned)
│   ├── polkit/                  # (Phase 7, planned)
│   └── <name>-dinit/            # generated thin packages
│       ├── APKBUILD
│       └── <name>               # dinit service file
├── feralos.pub
├── .github/workflows/build.yml
├── PLAN.md · STATUS.md · README.md
└── docs/                        # CI.md · PACKAGES.md · REPO-SETUP.md · etc.
```
