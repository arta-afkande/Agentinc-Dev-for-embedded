---
name: embedded-bug-review
description: Review C/C++ embedded code for common programming mistakes and functional bugs - undefined behavior, resource leaks, ISR/volatile/concurrency errors, timing, state machines, MISRA/CERT-style pitfalls. Use when reviewing C/C++ firmware changes for correctness (not security-specific).
---

# Embedded C/C++ Bug & Common-Mistake Review

Project-agnostic. First detect: language standard (C99/C11/C++14/17...), compiler, target arch/word size, RTOS or bare metal, coding standard (MISRA/CERT/in-house), dynamic allocation policy. Respect the project's conventions; do not impose style preferences.
Security-exploitability analysis belongs to `embedded-security-review`; mention a security smell briefly and point to it.

## Checklist

**Undefined / unspecified behavior**
- Signed overflow, shifts by >= width or negative, shifting into sign bit, division by zero, `INT_MIN / -1`.
- Uninitialized variables (incl. struct members, partially filled structs), use of indeterminate values.
- Strict aliasing violations, misaligned access, pointer arithmetic outside an object, comparing unrelated pointers, modifying string literals / const data.
- Missing `return` in non-void function, side effects with unspecified evaluation order (`a[i] = i++`), sequence-point issues.
- Enum/bool/integer conversions, implicit narrowing, `char` signedness assumptions, `sizeof(ptr)` vs `sizeof(array)`, `sizeof` on array parameters.
- Struct padding/endianness/packing assumptions when serialising; `#pragma pack` + taking member addresses.

**Control flow & logic**
- `=` vs `==`, missing `break` in switch (undocumented fallthrough), missing `default`, dangling `else`, macros without parentheses or multiple evaluation, `if (x);`.
- Off-by-one in loops/buffers, loop counters of too-small type (`uint8_t` iterating 256), unsigned `>= 0` / `i--` loops that never end.
- Wrap-around in tick/timer arithmetic: compare with `(int32_t)(now - deadline) >= 0`, not `now >= deadline`.
- Floating point: `==` comparison, float in ISR on MCUs without FPU/lazy stacking, double promotion, `printf` of floats not supported by nano-libc.
- Dead/unreachable code, unused results, redundant checks that the compiler removes.

**Resource & memory handling**
- Leaks on error paths (memory, handles, mutexes, locks not released, peripherals not disabled), double free, use-after-free, free of non-heap pointer, `malloc` unchecked, heap use where policy forbids.
- Stack usage: big locals, recursion, deep call chains, per-task stack sizing; missing stack watermark checks.
- Static/global state shared by functions that must be reentrant; `static` locals in multi-task functions.
- Ownership/lifetime: pointers to stack data passed to async APIs/queues/DMA, buffers reused before transfer completes.

**Interrupts, concurrency, hardware**
- Shared variables between ISR and main without `volatile` + atomic access/critical section; multi-word reads torn by interrupts; read-modify-write on registers/flags shared with ISR (`flags |= x`).
- Long ISRs, blocking/RTOS-non-ISR-safe calls in ISR (`xQueueSend` vs `...FromISR`), `printf`/malloc in ISR, forgetting to clear the interrupt flag, missing memory barriers/cache maintenance for DMA, write-buffer/posted-write ordering (read-back before enabling).
- Deadlock/lock-order, priority inversion, missed wakeups, mutex used from ISR, no timeouts on blocking waits, busy-wait loops without timeout/watchdog consideration.
- Peripheral register access: wrong bit masks/widths, read-to-clear side effects on reads, missing `volatile`, clock/pin not enabled before use, init order, magic numbers instead of named fields.
- Watchdog: fed from a timer ISR (masks hangs), fed in too many places, not fed during long flash ops.
- Power/reset: flash/EEPROM write endurance in hot loops, writes not power-fail safe, no brown-out handling, state not reinitialised after soft reset.

**Error handling & robustness**
- Ignored return values / error codes, errors not propagated, `assert` used for runtime error handling, inconsistent error conventions.
- No timeouts/retries bounds on comms, no recovery from bus errors (I2C stuck, UART overrun/framing), unbounded queue growth, queue full not handled.
- State machines: unhandled states/events, missing transition on error/timeouts, illegal-state default doing nothing.

**C++ specifics (when applicable)**
- Exceptions/RTTI/heap in disabled-feature builds, virtual calls/dynamic_cast in ISRs, object slicing, missing `override`/virtual destructor, rule-of-0/3/5, copy of large objects by value, `static` init order, `std::function`/`std::string`/containers hidden allocations, `constexpr`/`const`-correctness, uninitialized members, lifetime of temporaries bound to references, `string_view` dangling.

**Maintainability that causes bugs**
- Magic numbers, duplicated logic, long functions, deep nesting, ambiguous units (ms vs ticks), global mutable state, missing `const`, inconsistent types for same quantity, copy/paste errors (similar-named variables swapped), stale comments contradicting code.
- Preprocessor: unguarded headers, macro side effects, `#if` config combos not compiled/tested, `#define` used where `static inline`/`constexpr` is safer.

## Method
1. Read the code and its callers/callees enough to understand intent before judging.
2. Prefer findings with a concrete failing scenario (inputs/state/timing -> wrong result). Drop speculative style nits unless asked.
3. Optionally run read-only tooling if present: `cppcheck --enable=warning,style,performance,portability`, `clang-tidy` (`bugprone-*`, `cert-*`, `misc-*`), compiler `-Wall -Wextra -Wconversion -Wshadow`. Note if unavailable; do not install.
4. Check the project's own standard (MISRA etc.) only if declared.

## Severity
- **High**: wrong behavior/crash/hang in normal operation, data corruption, UB reachable in practice.
- **Medium**: bug on error/edge/timing paths, leaks, race windows.
- **Low**: latent issue, robustness, maintainability risks.
Add **confidence** (High/Med/Low).

## Report format
```
## Code Review: <scope>
Summary: <2-3 lines, counts per severity>

### [SEV] <short title>  (confidence: H/M/L)
- Location: path:line
- Problem: <what is wrong>
- Scenario: <when it fails>
- Fix: <concrete change>

### Not reviewed / assumptions
```
Order by severity; be concise; say what was checked if nothing was found.
