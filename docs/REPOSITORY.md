# APK Repository (FeralOS)

> Host: **Gitea Pages** (gitea.com — already our git host; own releases, own tags).
> Nested clone inside skeaAlpineInstaller with `.git` kept; outer repo ignores it.

## Repository Layout (published)

```
https://feralos.gitea.io/apk-repo/        (or Gitea Pages URL)
├── feralos.pub                           # abuild public key
└── v3.24/
    ├── main/
    │   └── x86_64/
    │       ├── APKINDEX.tar.gz
    │       ├── dinit-chimera-0.99.24-r0.apk
    │       ├── sd-tools-0.1.0-r0.apk
    │       └── sshd-dinit-0.1.0-r0.apk
    └── edge/
        └── x86_64/…
```

Per-branch dirs mirror Alpine convention (`v3.24`, `edge`) so clients pin stability.

## Source Repo Layout (feralos-aports, nested clone)

```
skeaAlpineInstaller/
└── feralos-aports/            # own .git, own tags/releases
    ├── src/                   # ALL packages — one dir per package
    │   ├── dinit-chimera/{APKBUILD,dinit-devd,dinit-cryptdisks,sysctl/10-feralos.conf}
    │   ├── sshd-dinit/APKBUILD    # Phase 3…
    │   └── …
    ├── docs/
    ├── feralos.pub
    └── .github/workflows/build.yml
```

Outer `.gitignore` entry (add once):

```
# nested repo — managed separately, own releases
feralos-aports/
```

## CI (Gitea Actions, draft)

```yaml
name: build
on: [push, tag]
jobs:
  build:
    runs-on: ubuntu-latest
    container: alpine:latest   # latest stable — coherent with branch: latest-stable
    steps:
      - run: apk add alpine-sdk git
      - uses: actions/checkout@v4
      - name: import signing key
        run: echo "${{ secrets.ABUILD_PRIVKEY }}" > ~/.abuild/${{ secrets.ABUILD_KEYNAME }}.rsa
      - name: build all
        run: |
          for d in src/*/APKBUILD; do
            cd "$d" && abuild -F && cd "$OLDPWD"
          done
      - name: index
        run: |
          apk-index() { apk index --allow-untrusted --rewrite-arch x86_64 \
            -o APKINDEX.tar.gz --description "FeralOS $1" packages/*/*.apk; }
      - name: deploy pages
        run: .ci/push-pages.sh   # commit packages/ to pages branch, tag → v3.24 dir
```

Refine runner details at impl time (Gitea Actions runner + pages enabling).

## Client Setup (inside FeralOS chroot / installed system)

```sh
# trust (installer copies key before apk update)
curl -fsSL https://<pages-url>/feralos.pub \
    -o /etc/apk/keys/feralos.rsa.pub      # name must match key CN

# repository
echo "https://<pages-url>/v3.24/main" >> /etc/apk/repositories

apk update && apk add dinit-chimera   # pulls dinit, sd-tools, snooze, eudev
```

Local testing without CI:

```sh
abuild -F
apk add --repository ~/packages/x86_64/ --allow-untrusted dinit-chimera
```

## Versioning & Releases

| Package | Version source | Update action |
|---------|---------------|---------------|
| `dinit` | Alpine community | none — tracks Alpine |
| `dinit-chimera` | upstream git tag (`v0.99.24`) | bump `pkgver`, rebuild |
| `sd-tools` | upstream git tag | bump `pkgver`, rebuild |
| `*-dinit` | ours | `pkgrel` bump |

Repo release = git tag in `feralos-aports` (`apk-repo/v3.24.0`) → CI republishes
indexed tree. Installer pins by adding the matching branch URL.

## Signing

`abuild-keygen -a -n` once; private key in CI secrets (`ABUILD_PRIVKEY`), public key
committed as `feralos.pub` + copied to `/etc/apk/keys/` by the installer. All packages
and `APKINDEX.tar.gz` signed (`apk index` signs automatically when key present).
