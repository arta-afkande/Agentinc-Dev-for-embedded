---
name: embedded-obsolete-code-review
description: Find obsolete, deprecated, dead or legacy code in C/C++ embedded projects - deprecated language/library/vendor APIs, outdated idioms, dead code, stale workarounds, abandoned dependencies. Use when reviewing C/C++ firmware for code that should be modernized, replaced or removed.
---

# Embedded C/C++ Obsolete Code Review

Project-agnostic. Detect first: language standard in use and the toolchain's supported maximum (build files, `-std=`), compiler/version, vendor SDK/HAL/RTOS and their versions, coding standard, and whether the project is constrained to old toolchains. Only recommend upgrades the toolchain and project policy allow; flag the constraint instead of assuming.

## What to look for

**Deprecated / removed language & library features**
- C: K&R function definitions, implicit `int`/implicit function declarations, `gets`, `register`, trigraphs, hand-rolled `bool`/fixed-width typedefs where `<stdbool.h>`/`<stdint.h>` exist, `volatile` as synchronisation.
- C++: `auto_ptr`, `register`, `throw()` specs, `std::bind1st/2nd`, `random_shuffle`, `std::unary_function`, C-style casts, `NULL` instead of `nullptr`, `typedef` vs `using`, raw `new/delete` where RAII fits, `enum` vs `enum class`, manual loops vs algorithms (only if allowed), pre-C++11 idioms, `volatile` compound ops deprecated in C++20.
- Banned/legacy libc: `strcpy`, `sprintf`, `atoi`, `rand`, `bzero`, `bcopy`, `ftime`, `gets`, `tmpnam`; unbounded variants with bounded replacements (`snprintf`, `strnlen`, `strtol`).
- Compiler-specific obsolete constructs: old `__attribute__`/`#pragma` forms, compiler-version `#if` branches for versions no longer supported, deprecated intrinsics.

**Deprecated vendor / RTOS / third-party APIs**
- Calls to functions marked `deprecated`, legacy HAL/LL/SPL drivers, old CMSIS versions, RTOS v1 APIs (e.g. CMSIS-RTOS v1), removed config macros, old SDK compatibility shims.
- Vendored libraries with outdated versions, forked-and-forgotten copies, unmaintained or EOL dependencies, known-vulnerable versions (report; verify against upstream advisories only if network allowed, otherwise say unverified).
- Hardcoded workarounds for errata/bugs in silicon, SDK or compiler versions that are no longer in use.

**Dead & redundant code**
- Unused functions, variables, macros, includes, files not in any build target; `#if 0` blocks; commented-out code; unreachable branches; feature flags that are always on/off; config options with no remaining users.
- Duplicate implementations of the same helper; wrappers that only forward; compatibility layers for removed platforms/boards.
- Stale TODO/FIXME/HACK referencing finished or abandoned work; comments or docs contradicting the code.

**Outdated build & tooling**
- Old `-std=` with newer features hand-emulated, disabled warnings left from old code, obsolete Makefile/CMake patterns (`CMAKE_MINIMUM_REQUIRED` very old, global `include_directories`), unmaintained build scripts, pinned old toolchain without reason.

## Method
1. Establish what is in the build (follow build files) so dead-code claims are based on the build graph, not just text search.
2. For "unused" claims: grep all references including macros, linker scripts, startup files, ISR vector tables, weak-symbol overrides, function pointers/callback tables, and generated code. Interrupt handlers and `extern "C"` entry points are used implicitly.
3. For deprecated APIs: check the header/doc in the repo (`__attribute__((deprecated))`, release notes, migration guides) before asserting; say when unverified.
4. Optional read-only tooling if present: compiler `-Wdeprecated-declarations -Wunused -Wunreachable-code`, `cppcheck --enable=unusedFunction`, `clang-tidy` (`modernize-*`, `misc-unused-*`), linker `--gc-sections --print-gc-sections`.
5. Prefer low-risk wins; for each recommendation note the risk of changing it (behavior, code size, timing, certification/qualified code) - on safety-certified code, flag, don't push.

## Severity
- **High**: deprecated/removed API about to break the build or a known-vulnerable/EOL dependency in use.
- **Medium**: deprecated API or dead code that hides bugs or misleads, workarounds with significant maintenance cost.
- **Low**: modernization, cleanup, cosmetic.
Add **confidence** (High/Med/Low); "unused" findings are only High with build-graph evidence.

## Report format
```
## Obsolete Code Review: <scope>
Summary: <2-3 lines, counts per severity>

### [SEV] <short title>  (confidence: H/M/L)
- Location: path:line
- Obsolete because: <deprecated since / dead because / outdated how>
- Replacement / action: <modern API, remove, or keep and why>
- Risk of change: <behavior/size/timing/certification>

### Not reviewed / assumptions
```
