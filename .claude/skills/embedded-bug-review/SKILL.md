---
name: embedded-bug-review
description: Review C/C++ embedded code for common programming mistakes and functional bugs - undefined behavior, resource leaks, ISR/volatile/concurrency errors (races, deadlocks, memory ordering), timing, state machines, MISRA/CERT-style pitfalls - and suggests best practices. Use when reviewing C/C++ firmware changes for correctness (not security-specific).
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

**Concurrency review (threads, tasks, ISRs, DMA, multi-core)**
First map the concurrency model: list execution contexts (ISRs by priority, tasks, threads, cores, DMA engines), every shared object, and which primitive protects each. Then check:
- Data races: shared data accessed from 2+ contexts with no common protection; "benign" races on multi-word/struct/64-bit values (torn on 8/16/32-bit MCUs); non-atomic read-modify-write (`cnt++`, `flags |= x`, bitfields sharing a word); `volatile` used as synchronisation; check-then-act (TOCTOU) across a context switch or unlock/lock gap.
- Atomics & memory ordering: `memory_order_relaxed` where acquire/release is needed; flag-then-data publication without barriers (`dmb`/`dsb`/`isb`, `std::atomic_thread_fence`); double-checked locking; ABA in lock-free structures; lock-free code where a mutex/critical section would be correct and simpler; SMP/multi-core cache coherency and DMA cache clean/invalidate.
- Locking discipline: inconsistent lock order (deadlock), lock held across blocking calls/callbacks/user code, recursive locking on non-recursive mutex, unlock on wrong path or missing on early return/error (no RAII), lock granularity that leaves invariants broken between locks, mutex used from ISR, lock-protected data also touched lock-free elsewhere.
- Scheduling hazards: priority inversion (no priority inheritance), starvation, busy-wait/spin on a lower-priority producer, missed wakeups/lost signals (condition check outside the lock, notify before wait, no predicate loop), spurious wakeups, event flags cleared by the wrong party, unbounded blocking without timeout.
- ISR <-> task handoff: queue/ring-buffer SPSC vs MPMC misuse, index wrap and full/empty ambiguity, producer/consumer both writing a shared index, ISR-safe API variants, deferred work bounded, interrupts disabled/re-enabled symmetrically (save/restore state, not blind enable), nested critical sections.
- Lifetime across contexts: object destroyed/freed while another context still uses it, stack buffers handed to other tasks/DMA, thread/task start-up and shutdown ordering, init-before-use races (object published before fully constructed, `static` local/global init races), callbacks invoked after deregistration.
- Shared resources: non-reentrant libc/driver calls from several tasks, peripheral/bus (SPI/I2C/UART) used by multiple tasks without an owner or mutex, `errno`/global status clobbered, shared logging/printf.
- Suggest verification: TSan/Helgrind on a host build, stress with randomised timing/priority, lock-order/assert-held checks, static annotations (`GUARDED_BY`, `-Wthread-safety`), RTOS trace tools.
Report each as `[CONC]` with the interleaving that breaks it (context A does X, preempted/interrupted by B doing Y -> wrong state).

**Error handling & robustness**
- Ignored return values / error codes, errors not propagated, `assert` used for runtime error handling, inconsistent error conventions.
- No timeouts/retries bounds on comms, no recovery from bus errors (I2C stuck, UART overrun/framing), unbounded queue growth, queue full not handled.
- State machines: unhandled states/events, missing transition on error/timeouts, illegal-state default doing nothing.

**C++ specifics (when applicable)**
- Exceptions/RTTI/heap in disabled-feature builds, virtual calls/dynamic_cast in ISRs, object slicing, missing `override`/virtual destructor, rule-of-0/3/5, copy of large objects by value, `static` init order, `std::function`/`std::string`/containers hidden allocations, `constexpr`/`const`-correctness, uninitialized members, lifetime of temporaries bound to references, `string_view` dangling.

**Maintainability that causes bugs**
- Magic numbers, duplicated logic, long functions, deep nesting, ambiguous units (ms vs ticks), global mutable state, missing `const`, inconsistent types for same quantity, copy/paste errors (similar-named variables swapped), stale comments contradicting code.
- Preprocessor: unguarded headers, macro side effects, `#if` config combos not compiled/tested, `#define` used where `static inline`/`constexpr` is safer.

**Best practices to suggest (non-defect improvements)**
Offer these as `[BEST-PRACTICE]` suggestions only when they would clearly reduce risk or cost in the reviewed code; keep to the project's declared standard and avoid style-preference noise. Each needs a concrete, small change and the benefit.
- Concurrency design: prefer immutability > message passing > atomics > mutex > critical section; encapsulate lock/atomic inside the type; RAII lock guards; document ownership and threading contract (ISR-safe? thread-safe?); single owner per peripheral; keep critical sections and ISRs short; bounded waits with timeouts.
- Robustness: check and propagate every error; defensive input validation at module boundaries; fail-safe defaults; bounded loops/buffers/queues; watchdog fed from a supervising task that checks health.
- Types & interfaces: fixed-width types, `enum class`/named constants, units in names, `const`/`static` correctness, narrow interfaces, `static_assert` for size/layout/alignment assumptions.
- Testability & diagnosability: HAL seams for hardware, deterministic time source, assertions for invariants, error counters/logging that are ISR-safe.
- Tooling: enable `-Wall -Wextra -Wconversion -Wshadow` (warnings as errors), run static analysis and sanitizers (ASan/UBSan/TSan) in CI, stack watermark/usage checks.

## Method
1. Read the code and its callers/callees enough to understand intent before judging.
2. Prefer findings with a concrete failing scenario (inputs/state/timing -> wrong result). Drop speculative style nits unless asked.
3. Optionally run read-only tooling if present: `cppcheck --enable=warning,style,performance,portability`, `clang-tidy` (`bugprone-*`, `cert-*`, `misc-*`), compiler `-Wall -Wextra -Wconversion -Wshadow`. Note if unavailable; do not install.
4. Check the project's own standard (MISRA etc.) only if declared.

## Severity
- **High**: wrong behavior/crash/hang in normal operation, data corruption, UB reachable in practice, data race or deadlock on a normal path.
- **Medium**: bug on error/edge/timing paths, leaks, narrow race windows, rare deadlocks.
- **Low**: latent issue, robustness, maintainability risks.
- Best-practice suggestions are not defects: list them separately after the findings, without severity.
Add **confidence** (High/Med/Low).

## Report format
```
## Code Review: <scope>
Summary: <2-3 lines, counts per severity>

### [SEV] [BUG|CONC] <short title>  (confidence: H/M/L)
- Location: path:line
- Problem: <what is wrong>
- Scenario: <when it fails; for CONC the exact interleaving>
- Fix: <concrete change>

### Best-practice suggestions
- [BEST-PRACTICE] <suggestion> - <benefit> - <small concrete change>

### Not reviewed / assumptions
```
Order by severity; be concise; say what was checked if nothing was found.
