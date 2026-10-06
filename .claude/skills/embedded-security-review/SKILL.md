---
name: embedded-security-review
description: Security review checklist for C/C++ embedded firmware - memory safety, input validation, integer issues, crypto/secrets, update/boot chain, debug interfaces, RTOS/ISR hazards. Use when auditing C/C++ code for vulnerabilities or reviewing changes that touch parsers, protocols, buffers, crypto, bootloaders or privileged code.
---

# Embedded C/C++ Security Review

Project-agnostic. Discover the target first (toolchain, MCU/arch, RTOS, libc, build flags, attack surface), then apply the checklist. Do not assume a platform.

## 1. Scope the attack surface
Identify every place untrusted data enters: UART/USB/CAN/SPI/I2C/BLE/Wi-Fi/Ethernet, network stacks, file/flash/EEPROM contents, OTA images, bootloader commands, debug/CLI consoles, interrupts/DMA buffers, shared memory with other cores/privilege levels. Review those paths first, following data from entry to sink.

## 2. Checklist (by priority)

**Memory safety**
- Unbounded copies/format: `strcpy strcat sprintf vsprintf gets scanf("%s") strncpy`(no NUL guarantee) `memcpy` with attacker-influenced length.
- Off-by-one, missing NUL terminator, array index from external data without bounds check.
- Length fields from packets trusted without checking against buffer size AND remaining packet bytes.
- Stack buffers sized by external input, VLAs, `alloca`; large stack frames in tasks with small stacks.
- Use-after-free, double free, returning pointers to locals, dangling pointers to DMA/ISR buffers, uninitialized reads (info leak via padding/struct copy to wire).
- Heap use in safety/security paths (fragmentation, failed `malloc` unchecked, `malloc(a*b)` overflow).
- Unaligned access/type-punning of packet buffers (UB, faults); prefer memcpy into a struct or explicit byte parsing.

**Integer issues**
- Overflow/wrap in size/offset/length arithmetic before allocation or bounds checks; signed/unsigned comparison; truncation (`uint32_t`→`uint16_t`/`uint8_t`); implicit promotions; negative values used as size; `abs(INT_MIN)`.
- Check order: validate operands before arithmetic, not the result after wrap.

**Input validation & parsing**
- Every field validated (range, enum, length, state) before use; reject, don't "fix up".
- State machine errors: accepting messages in wrong state, no timeout, unbounded loops/retries, recursion depth from input.
- Format string: user data as format argument (`printf(buf)`, logging macros).
- Command injection via `system`/`popen` (Linux-based embedded), path traversal in file APIs.

**Concurrency / interrupts / RTOS**
- Races between ISR and task on shared data (missing `volatile`/atomics/critical section; `volatile` is not atomicity); TOCTOU on buffers filled by DMA; non-reentrant functions in ISRs; blocking calls in ISR; priority inversion on security-relevant locks; check-then-use across context switches.
- Buffer ownership handoff between ISR/DMA/task without clear lifetime.
- Deadlock/livelock reachable by an external party (attacker-triggered lock contention or blocking waits = DoS); shared secrets/keys accessed without protection across contexts. General race/ordering correctness is covered by `embedded-bug-review` (`[CONC]`).

**Crypto & secrets**
- Hardcoded keys, passwords, tokens, certificates, default credentials; secrets in logs, in flash readable via debug port, in version control.
- Home-grown crypto, ECB, static IV/nonce reuse, `rand()`/timer-seeded PRNG for security, no hardware RNG health check.
- Non-constant-time comparison of MACs/tokens (`memcmp`/`strcmp`); keys not zeroized (`memset` optimized away - use `memset_s`/explicit_bzero/volatile loop).
- Missing signature verification, verification result ignored, verify-then-use TOCTOU (image verified in RAM/flash then re-read), rollback not prevented (no version counter), weak/absent anti-downgrade.

**Boot, update & device hardening**
- Secure boot chain: signature check before executing/jumping, bounds on image header fields, vector table/entry validation, fail-closed on error.
- OTA: authenticated + integrity-checked + versioned; power-fail safe; no partial-image execution.
- Debug interfaces (JTAG/SWD/UART bootloader/test commands) left enabled in production; readout protection; MPU/MMU/TrustZone configuration; stack canaries / W^X / `-fstack-protector` where supported; privileged code reachable from unprivileged without validation (syscall/SVC argument checking, pointer validation).
- Fault injection / glitching: security decisions made on a single branch/bool; return codes compared to a non-hamming-distance success value (flag only if the threat model includes physical attacks).

**Error handling**
- Unchecked return values on security-relevant calls; fail-open defaults; error paths that leak resources or leave partially-initialized state; assertions used as security checks (compiled out with NDEBUG).

**C++ specifics**
- Exceptions/RTTI assumptions in no-exception builds, `new` failure semantics, iterator invalidation, rule of 3/5 violations with raw owning pointers, `reinterpret_cast`/`const_cast` abuse, `std::string`/`vector` use in ISR or hard real-time paths, static init order.

**Build / tooling**
- Missing warnings (`-Wall -Wextra -Wconversion -Wformat=2 -Wformat-security -Wshadow`), no static analysis, no sanitizer or fuzz coverage on parsers (host builds), unpinned/unverified third-party libraries, known-vulnerable vendor SDK/stack versions.

## 3. Method
1. Map entry points and trust boundaries.
2. Trace each tainted input to sinks (copies, indexes, loops, allocation, format, crypto, privileged calls).
3. Check bounds, types, and ordering at each hop; consider the worst-case attacker-controlled value.
4. Only report issues you can justify from the code. Read the surrounding code before claiming a bug; state assumptions explicitly (e.g. "assumes `len` comes from the wire").
5. Where useful and available, run tooling (read-only): `cppcheck --enable=all`, `clang-tidy` (`clang-analyzer-*`, `cert-*`, `bugprone-*`), `gcc -fanalyzer`, `grep` for banned functions. Report tool absence rather than installing.

## 4. Severity
- **Critical**: remote/unauthenticated memory corruption or code exec, auth/secure-boot bypass, extractable key material.
- **High**: memory corruption needing local/adjacent access or specific state; missing signature checks; info leak of secrets.
- **Medium**: DoS (hang, crash, resource exhaustion), weak crypto use, hardening gaps with plausible exploit path.
- **Low / Info**: defense-in-depth, style that hides risk.
Also give **confidence** (High/Med/Low).

## 5. Report format
```
## Security Review: <scope>
Summary: <2-3 lines, counts per severity>

### [SEV] <short title>  (confidence: H/M/L)
- Location: path:line
- Issue: <what and why it is exploitable; attacker input and path>
- Evidence: <short code excerpt>
- Fix: <concrete change, ideally a small snippet>

### Not reviewed / assumptions
```
Order by severity. No padding; if nothing found, say what was checked.
