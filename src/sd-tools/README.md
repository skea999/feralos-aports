# sd-tools

Standalone utilities from systemd (`sd-tmpfiles`, `sd-sysusers`, ...). FeralOS
overrides Alpine's package because Alpine's build is **broken at runtime**.

- Base: Alpine **community/sd-tools 0.99.0-r3** (v3.24 + edge), adapted.
- Upstream source: https://github.com/chimera-linux/sd-tools tag `v0.99.0`.
- Version: `_upstream=0.99.0`, `pkgver=989.0.99.0`, `pkgrel=0`.

## Why the override: use-after-scope (upstream #5)

`CONF_PATHS_STRV()` is a C11 compound literal with **automatic storage duration
scoped to the enclosing block**. In `run()` the literal is created inside the
`switch()` body, stored in `config_dirs`, and dereferenced *after* the switch
ends (`STRV_FOREACH` debug loop, `cat_config`, `read_config_files`,
`parse_arguments`):

```c
case RUNTIME_SCOPE_SYSTEM:
        config_dirs = CONF_PATHS_STRV("tmpfiles.d");  /* literal dies here */
        break;
}                                                      /* block ends */
...read_config_files(&c, config_dirs, ...)             /* reads dead stack */
```

clang happens to keep the dead stack slot intact, masking the bug; GCC 14+
actively reuses the slot (`-Wdangling-pointer`), so the strings turn into
garbage and `sd-tmpfiles` segfaults on every `--create`/`--cat-config` run
(stack-use-after-scope confirmed with ASan in
[upstream issue #5](https://github.com/chimera-linux/sd-tools/issues/5)).

Our `tmpfiles-config-dirs-lifetime.patch` copies the four paths into a
file-scope array with **static storage duration**, so the pointer stays valid
for the lifetime of the program. `CONF_PATHS_USR` expands to plain
string-literal concatenations, so the static array is valid.

Other deviations from Alpine's APKBUILD:

- Alpine's `drop-bash-dep.patch`, `32bit.patch` and `gcc.patch` are not used;
  `checkdepends="bash"` covers the test script shebang instead (bash exists on
  FeralOS), and the other two are irrelevant for our arch/build combo.
- `build()` uses plain `meson setup` (not `abuild-meson`) to keep the explicit
  `-Dacl=enabled`: all optional deps enabled (FeralOS build rule).

## Removal condition

This override exists **only** because of upstream issue #5. When Alpine's
sd-tools build carries the upstream fix (new upstream tag with the static
storage fix, or Alpine adding the equivalent patch):

1. Drop `tmpfiles-config-dirs-lifetime.patch` and the `_upstream` override
   (plain `pkgver` again).
2. Delete this aport (or revert it to a verbatim Alpine copy) so the Alpine
   package is selected again.
3. Re-run the `sd-tmpfiles --create` smoke test in CI to confirm.

## Update procedure (while the override is still needed)

1. If upstream tags a new version, bump `_upstream`, reset `pkgrel=0`, refresh
   the tarball sha512.
2. Rebase `tmpfiles-config-dirs-lifetime.patch` if `run()` context moved; keep
   the `Patch-Source`/issue reference header.
3. Rebuild in docker `alpine:latest` (`abuild -Fr`) and confirm
   `sd-tmpfiles --create --boot` exits 0/65/73 (not 139/134).

## Version scheme

`pkgver=989.<upstream>`: the 989 major component always outranks any Alpine
version field-by-field (apk numeric compare), so our fixed build is selected
over Alpine's `0.99.0-r3`. Bump the suffix in lockstep with upstream.
