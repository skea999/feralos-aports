# Port to Self-Hosted Infrastructure (Gitea + native Alpine runner)

> **Status**: PROPOSAL — not scheduled. Trigger: self-hosting phase
> (see `PLAN.md` → Backlog). Nothing in the current pipeline depends on this.
> **Scope**: move repo + CI/CD from GitHub (Actions + Pages) to a self-hosted
> Gitea instance with a native Alpine runner, keeping the published repo URL
> scheme and signing keys coherent.

## Goal

FeralOS builds on FeralOS infrastructure: the aports repo, its CI, and the
published package repository run on self-hosted Gitea, with a **native Alpine
VM as the runner**. Client-facing behavior (apk add from a signed HTTPS repo)
stays byte-for-byte identical.

## Reality check: Gitea has NO native Pages

GitHub Pages has no direct equivalent in Gitea core. Options, ranked:

| Option | What | Trade-off |
|--------|------|-----------|
| **gitea-pages-server** (recommended) | [Codeberg's pages server](https://codeberg.org/Codeberg/pages-server), open source, self-hosted next to Gitea; serves sites from a `pages` branch or custom domains | one extra service to run; behavior closest to GitHub Pages |
| nginx raw proxy | subdomain (e.g. `pages.feralos.org`) reverse-proxying Gitea raw URLs of a `pages` branch | only nginx; URL mapping rules to maintain |
| plain raw URLs | `https://git.feralos.org/feralos/apk-repo/raw/branch/pages/...` | works with apk **today**; ugly URLs; couples clients to git layout |

`apk` only needs a stable HTTPS base serving `APKINDEX.tar.gz` + `*.apk` +
`feralos.pub` — all three options satisfy it. Keep the path scheme identical
(`v3.24/main/x86_64/APKINDEX.tar.gz`) so clients and installer never change logic,
only a URL constant.

## Migration map (GitHub → self-hosted Gitea)

| Component | Now (GitHub) | Target (Gitea self-hosted) | Notes |
|-----------|--------------|----------------------------|-------|
| Repo | github.com/skea999/feralos-aports | `git.feralos.org/feralos/apk-repo` | seed via `git push --mirror`, then switch origin |
| CI | GitHub Actions | **Gitea Actions** (built-in, GH-compatible syntax) | same `build.yml`; audit env differences only |
| Runner | GitHub-hosted Ubuntu VM + container | **act_runner on an Alpine VM** (self-hosted) | the actual Alpine-VM goal |
| Build env | `container: alpine:latest` | keep (runner is Alpine, but container preserves hermetic parity with CI history) | optional to drop |
| Pages | `actions/deploy-pages` | gitea-pages-server or nginx raw proxy | see options above |
| Secrets | Repository secrets | Gitea repo/org secrets | same names: `ABUILD_PRIVKEY`, `ABUILD_KEYNAME` |
| Pages URL | skea999.github.io/feralos-aports | `pages.feralos.org` (or equivalent) | one-line change in installer + client docs |

## Native Alpine runner setup (act_runner)

Gitea's Actions runner is **act_runner**:

```sh
# on the Alpine VM (kernel: any Linux; userland: Alpine)
wget https://gitea.com/gitea/act_runner/releases/latest/download/act_runner-<ver>-linux-amd64 -O /usr/local/bin/act_runner
chmod +x /usr/local/bin/act_runner

act_runner register \
  --instance https://git.feralos.org \
  --token <registration-token-from-gitea-admin> \
  --name alpine-vm-1 \
  --labels alpine-latest:docker://alpine:latest

# service: OpenRC unit running `act_runner daemon` as dedicated user
rc-update add act-runner default
```

Workflow change: `runs-on: alpine-latest` (the label). The Docker-in-Docker
question disappears if the container is dropped — but keeping
`container: alpine:latest` is recommended so CI execution history stays
hermetically identical to the GitHub era.

### Security on self-hosted runners

Secrets on machines you own shift the trust boundary:

- **Never run fork PR workflows** on the production runner (same exfiltration
  risk as GitHub self-hosted; Gitea: require approval for PR runs, or disable
  PR trigger entirely — we only need `push` + `tag`)
- Restrict the runner registration to the `feralos` org
- Keep the signing-key rotation policy from `docs/CI.md`
- Runner user dedicated, no sudo, ephemeral workspace

## Migration checklist (execute only when triggered)

- [ ] Provision Alpine VM (local QEMU/KVM or VPS), OpenRC service for act_runner
- [ ] Deploy gitea-pages-server (or nginx raw proxy) + TLS (ACME)
- [ ] Mirror repo to Gitea; configure `ABUILD_PRIVKEY` / `ABUILD_KEYNAME` secrets
- [ ] Adapt `build.yml`: `runs-on` label; optional container drop; audit
      `GITHUB_*` env vars used (replace with Gitea equivalents)
- [ ] First green run on Gitea; verify `APKINDEX.tar.gz` served over new domain,
      signature verifies with existing `feralos.pub` (client smoke: apk update)
- [ ] Flip installer + docs URLs (single constant swap; path scheme unchanged)
- [ ] Freeze GitHub Pages read-only for one release cycle, then archive

## Coherence guarantee

Client config is just **URL + pubkey**. Path scheme stays
`/<branch>/main/x86_64/APKINDEX.tar.gz` with `feralos.pub` at the root →
zero client logic changes, one URL swap. Signatures carry the key NAME
(`feralos`), not the platform — nothing to re-sign if we migrate before a key
rotation.
