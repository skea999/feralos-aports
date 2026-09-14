# Toolchain Decision: GCC / aports (final)

> **Decided**: 2026-09-10 — base Alpine stack, GCC, no LLVM, no clang.
> **Status**: CLOSED. Reopen only if the distro strategy changes.

## Decision

FeralOS packages build with **aports + abuild + GCC** (Alpine default toolchain).
Runtime = musl + libstdc++ (from GCC). No clang, no LLVM, no libc++.

## Facts that drove it (verified, kept for future reference)

**cports/cbuild** (Chimera):
- Written specifically for Chimera; build root = minimal **Chimera** package set
- Bootstrap toolchain = clang + lld + **libc++** + compiler-rt + LLVM libunwind
- Source bootstrap **explicitly unsupported on Alpine hosts** (patched musl SONAME —
  Usage.md §Bootstrap Requirements)
- Using it for our packages = building against libc++/chimerautils → binaries
  incompatible with FeralOS runtime (libstdc++)
- Output format IS apk (compatible), but package metadata references Chimera base

**Compiler vs runtime** (the rule that mattered):
- clang + libstdc++ = drop-in on Alpine (same Itanium ABI) — was viable but pointless
- libc++ runtime = every C++ package of Alpine must be rebuilt → distro fork

**Our C++ surface**: tiny — dinit-chimera helpers (12), sd-tools (2), turnstile (1).
Everything else is Go + shell + Alpine packages. GCC-vs-clang stakes were low;
consistency with Alpine toolchain wins.

## Not pursued

- **cports adoption**: build root is Chimera base; templates declare Chimera deps;
  Alpine host bootstrap unsupported. Targeting Alpine base = fork profiles + mini
  base = distro build system effort.
- **LLVM rebuild of Alpine**: every C++ package links libstdc++ or libc++ (never
  both) → full fork, perpetual maintenance. Equivalent to what Chimera did
  (they wrote cbuild for exactly this).
- **Base pivot to Chimera**: would give LLVM-complete for free but rewrites the
  installer (repos, `*-openrc` packages, cosmic/kde/niri, harness images).
