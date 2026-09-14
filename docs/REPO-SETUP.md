# Repository Setup on Alpine

How to configure an Alpine Linux system (installed FeralOS, live ISO, or a plain
Alpine chroot/container) to use the **FeralOS package repository**, and how to
verify it works.

## Repository facts

| Item | Value |
|------|-------|
| Published URL (packages) | `https://skea999.github.io/feralos-aports/feralos-aports/x86_64/` |
| Public key | `https://skea999.github.io/feralos-aports/feralos.pub` |
| Key file name on client | `/etc/apk/keys/feralos.rsa.pub` — MUST keep this exact name (signatures embed it) |
| Source repo | https://github.com/skea999/feralos-aports |
| Compatibility | Alpine `latest-stable` (v3.24) and edge, x86_64 |

Layout served by Pages:

```
/feralos.pub                              # public signing key
/feralos-aports/x86_64/APKINDEX.tar.gz    # signed package index
/feralos-aports/x86_64/*.apk              # signed packages
```

> NOTE: the doubled `feralos-aports/` path is NOT a typo — it is the Pages
> project path + the abuild `REPODEST` directory name (same word).

## Setup (client)

Run as root on any Alpine system with network access:

```sh
# 1. Trust our key — the filename is part of the signature scheme
wget -qO /etc/apk/keys/feralos.rsa.pub \
    https://skea999.github.io/feralos-aports/feralos.pub

# 2. Add the repository (append — do not replace the Alpine repos;
#    Alpine CDN serves the transitive dependencies of our packages)
echo "https://skea999.github.io/feralos-aports/feralos-aports/x86_64" \
    >> /etc/apk/repositories

# 3. Refresh indexes and install
apk update
apk add dinit-chimera        # example — pulls dinit, sd-tools, snooze, eudev
```

`apk update` verifies the `APKINDEX.tar.gz` signature against
`feralos.rsa.pub` — if it succeeds, the trust chain is already working.

## Verify the setup

```sh
# Which repository provided a package, and from which index
apk policy dinit-chimera

# Everything installed from our repo (spot check)
apk info | sort | grep -E 'dinit|sd-tools|turnstile'

# Signature check without installing (apk-tools 3)
apk fetch --stdout dinit-chimera | apk verify - 2>/dev/null \
    || apk add --simulate dinit-chimera
```

Expected: `apk policy` lists our repository URL as a source; installs run
**without** `--allow-untrusted` — if you ever NEED that flag, the key setup is
broken: fix it, do not work around it.

## Package origin policy

Rule 0 of this repo: **we use Alpine packages whenever they exist.** Our
repository only carries packages that are NOT in Alpine, or that need
FeralOS-specific patches (e.g. `polkit` with `turnstile.patch`).

- A package name may exist in BOTH repositories in the future (it happened with
  `sd-tools`: Alpine community ships a newer `0.99.0-r3`, we removed ours).
  When it does, either pin the exact version (`apk add pkg=1.2.3-r0`) or let
  apk resolve — Alpine's build is the trusted one in that case.
- `apk policy <pkg>` always shows which repository wins.

## Uninstall / disable

```sh
# remove just our repository line
sed -i '\|feralos-aports|d' /etc/apk/repositories
rm -f /etc/apk/keys/feralos.rsa.pub
apk update
```

Installed packages stay installed (and keep working); they just stop updating
from our repo.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `UNTRUSTED signature` | key missing, wrong name, or stale | re-run step 1; filename MUST be `feralos.rsa.pub` |
| `ERROR: unable to select packages` | package pinned/version conflict | `apk policy <pkg>`; remove pins |
| `404` on APKINDEX | wrong URL (check the doubled project dir) or Pages down | verify with `curl -I` against the layout above |
| `key feralos.rsa.pub is unknown` | key CN does not match filename | re-download the published `feralos.pub`; do not self-generate |
| index very old | `apk update` not run | run it; Pages deploys on every push to main |

## Maintainers: local build/test

See `README.md` (Build section) — requires `alpine-sdk`; packages build with
`abuild -Fr` and land in `~/packages/<pkgname>/x86_64/`. CI does the same in
`alpine:latest` on every push (`.github/workflows/build.yml`, guide in
`docs/CI.md`).
