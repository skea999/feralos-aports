# Dropped Optional Features

> Registry of optional features we had to DROP (rule 6). A feature lands here
> only when the build fails for any reason AND boot doesn't strictly need it.
> Each entry must carry a re-enable command and a retry condition, so we (or
> anyone else) can pick it up later.

## How to use

1. When a feature must be dropped: add a row below, document it in `STATUS.md`,
   reference it in the package's `APKBUILD` comment.
2. Retry condition = what has to change for the feature to come back (upstream
   fix, new toolchain, dependency available on Alpine, …).
3. When a feature is re-enabled: remove the row, bump `pkgrel`, note it in
   `STATUS.md`.

## Dropped features

| Date | Package | Feature (meson flag) | Why dropped | Re-enable | Retry condition |
|------|---------|----------------------|-------------|-----------|-----------------|
| 2026-09-26 | quickshell | crash-handler (`-DCRASH_HANDLER=OFF`) | cpptrace (stack-trace backend) is not packaged in Alpine | `-DCRASH_HANDLER=ON` | cpptrace lands in aports, or quickshell ships `VENDOR_CPPTRACE=ON` fallback that builds without a system cpptrace |

### Example entry (do not delete — format reference)

| 2026-XX-XX | sd-tools | acl (`-Dacl=enabled` → removed) | libacl headers conflict with musl 1.2.x on gcc 14 | `abuild-meson -Dacl=enabled` | alpine libacl-dev fixed / upstream patch merged |

## Never dropped — enabled by policy (rule 5)

| Package | Feature | State |
|---------|---------|-------|
| sd-tools | acl (`-Dacl=enabled`) | ✅ enabled (draft, Step 1a) |
| sd-tools | tests (`-Dtests=true`) | ✅ enabled (draft, Step 1a) |
