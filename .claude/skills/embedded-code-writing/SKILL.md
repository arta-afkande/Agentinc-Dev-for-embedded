---
name: embedded-code-writing
description: Conventions for writing new or modified C/C++ embedded code - small focused units, thread-safe-by-default objects, minimal comments, defensive and portable practices. Use when implementing features, fixes or refactors in C/C++ firmware.
---

# Embedded C/C++ Code Writing

Project-agnostic. Existing project conventions (naming, formatting, error style, coding standard, allocation policy, language standard) always win over the defaults here. Detect them from neighbouring code and build files before writing.

## Core rules

**Small units**
- Smallest change that solves the task; no unrequested refactors, features or abstractions.
- Small functions doing one thing; prefer early returns over deep nesting; roughly one screen max, split when a function mixes levels of abstraction.
- Small, focused files/modules and narrow interfaces; minimal headers (forward declarations, no unnecessary includes); minimise globals, keep file-local things `static`/anonymous namespace.
- Deliver in small increments: each step compiles and is reviewable on its own.

**Thread safety by default**
- If the code involves threads, tasks, ISRs, DMA or multiple cores, make objects thread-safe unless the user says otherwise: encapsulate the lock/atomic inside the type so callers cannot misuse it; no unprotected shared mutable state.
- Choose the lightest correct primitive: immutability/const > message passing (queue) > atomics > mutex > critical section (interrupt masking only for very short sections).
- ISR-shared data: ISR-safe API variants only, bounded work, no blocking or allocation; hand off to a task via queue/flag.
- Avoid holding locks across callbacks or blocking calls; consistent lock order; use timeouts on blocking waits where the platform allows; RAII lock guards in C++.
- Document the threading contract only where non-obvious (e.g. "callable from ISR"). If a type is deliberately not thread-safe, say so in one line.
- Before finishing concurrent code, self-check: every shared object has one named protection mechanism; consistent lock order; no lock held across callbacks/blocking calls; no check-then-act gap; correct memory ordering/barriers for flag-then-data handoffs; init/shutdown ordering safe; ISR work bounded.
- If no threads are involved, don't add locking.

**Comments**
- Do not comment every variable/function or restate the code. Names carry meaning.
- Comment only when necessary: non-obvious why, hardware quirks/errata, units and ranges not expressible in types, protocol/spec references, ordering/timing constraints, threading contract.
- No commented-out code, no change-log comments, no decorative banners.

## Defaults (when the project doesn't say otherwise)
- Fixed-width types for hardware/protocol data; named constants/enums instead of magic numbers; units in names (`timeout_ms`).
- Check every external input and every return value that can fail; propagate errors with the project's convention; never fail silently.
- Bounded loops and buffers; no unbounded recursion; no dynamic allocation after init if the project avoids heap; bounds checks before arithmetic can wrap.
- `const` correctness, `volatile` only for hardware/ISR-visible data (and not as synchronisation), `static` for internal linkage, narrow scopes, initialise at declaration.
- C++: RAII, rule of zero, `enum class`, `constexpr`, `nullptr`, no hidden allocation or exceptions/RTTI where disabled; keep ISR code free of heavy C++ features.
- Avoid banned/unsafe functions (`strcpy`, `sprintf`, `gets`); use bounded variants.

## Best practices to apply
- Make invalid states unrepresentable (enums, strong types, `static_assert` on size/layout); validate at module boundaries and trust internally.
- Prefer simple, auditable designs over clever ones (a mutex over lock-free unless measured need).
- Keep hardware access behind a thin HAL seam so logic is host-testable; inject time/clock sources.
- Fail safe: defined behavior on every error path, bounded retries/timeouts, release resources on all exits.
- Compile clean with strict warnings; run available static analysis/sanitizers.

## Workflow
1. Read the surrounding code and match its style.
2. Plan the smallest set of changes; for ambiguous requirements, state the assumption in one line rather than expanding scope.
3. Write the code; keep the diff tight.
4. Verify when possible: build/compile with the project's command, run existing tests, use warnings-as-errors if configured. Report honestly what was and wasn't run.
5. Summarise: what changed, assumptions, threading contract if any, and follow-ups you noticed but did not do.
