# AI Agent Usecase Helper

Base input for generating a project-specific `CLAUDE.md` (or `AGENTS.md`, Cursor rules, Copilot instructions, etc.) for C/C++ embedded projects.

**How to use:** give this file to an AI (Claude or any other) together with the target project, and ask it to produce the project's instruction file. The AI should (1) inspect the project to fill every `<PLACEHOLDER>` in section 4, (2) keep the generic rules from section 2, (3) drop anything that doesn't apply, and (4) ask the user only for what cannot be found in the repo.

For Claude Code, the agents and skills in `.claude/` of this repo implement these rules directly. For other AI tools, paste the relevant section 2 rules and the role prompts from section 3.

---

## 1. Available agents and skills (Claude Code)

| Agent | Purpose | Access | Skills | Model / effort / maxTurns |
|---|---|---|---|---|
| `embedded-code-writer` | Implement features, fixes, refactors | read/write | `embedded-code-writing` | sonnet / medium / 20 |
| `embedded-test-writer` | Write and run tests (host first, then HW/emulator) | read/write | `embedded-test-writing` | sonnet / high / 25 |
| `embedded-code-reviewer` | Bugs, common mistakes, concurrency issues, security, obsolete code, best-practice suggestions | read-only (instruction-enforced; has Bash for analyzers) | `embedded-bug-review`, `embedded-security-review`, `embedded-obsolete-code-review` | opus / high / 40 |
| `embedded-security-auditor` | Security-only audit | read-only | `embedded-security-review` | opus / max / 40 |

The last column is the starting configuration in each agent's frontmatter (`model`, `effort`, `maxTurns`). These are starting guesses: raise `maxTurns` if agents often stop with partial output, raise effort/model if results are shallow. There is no per-agent token cap in Claude Code; `maxTurns` is the only per-agent execution limit. Installed copies in a project keep their own values, so tune them there.

Suggested flow: **write code -> write tests -> review**. Security-sensitive changes (parsers, protocols, crypto, bootloader, update, privileged code) also go to the security auditor.

---

## 2. Generic rules (project-independent)

> Summary for tools without skill support. **Source of truth:** `.claude/skills/*/SKILL.md` (full detail). When a rule changes, edit the skill first, then update this summary.

### 2.1 General
- Project conventions (naming, style, error handling, coding standard, language standard, allocation policy) always win over these defaults. Detect them from neighbouring code and build files first.
- Don't assume a platform, MCU, RTOS or toolchain; detect it.
- Smallest change that solves the task. No unrequested refactors, features or abstractions.
- Report honestly: say what was built/run and the results, and what was not run.
- Never flash, erase, or otherwise touch hardware unless the user explicitly asks. Never install tools or modify the environment unasked.

### 2.2 Writing code
- Small units: small single-purpose functions, narrow interfaces, minimal headers, minimal globals, `static`/anonymous namespace for internals, early returns over deep nesting. Deliver in compilable increments.
- Thread safety by default: if threads, tasks, ISRs, DMA or multiple cores are involved, make objects thread-safe (lock/atomic encapsulated inside the type) unless told otherwise. Lightest correct primitive: immutability > message passing > atomics > mutex > short critical section. ISR code is bounded, non-blocking, no allocation. No locking where no concurrency exists.
- Comments: none per variable/function. Only when necessary: non-obvious why, hardware quirks/errata, units/ranges, spec references, ordering/timing constraints, threading contract. No commented-out code.
- Defaults: fixed-width types for hardware/protocol data; named constants over magic numbers; units in names (`timeout_ms`); check external input and fallible return values; bounded loops/buffers; bounds checks before arithmetic can wrap; `const` correctness; `volatile` only for hardware/ISR-visible data and never as synchronisation; avoid `strcpy`/`sprintf`/`gets`.
- C++: RAII, rule of zero, `enum class`, `constexpr`, `nullptr`; no hidden allocation, exceptions or RTTI where disabled; keep ISR code free of heavy C++ features.

### 2.3 Writing tests
- All tests live under the project's `tests/` subdirectory.
- Cover all aspects of the changed code and the affected area (callers, callees, shared state/resources), not just the touched lines. State the coverage plan; list covered/uncovered areas in the report.
- Run on the local machine first, then on hardware/emulator with minimal changes: one test source, two backends. Production code reaches hardware only via a HAL interface; host builds use mocks/fakes (`tests/mocks/`), target builds use the real HAL; selection via build configuration, never `#ifdef` in test bodies. Hardware-only tests go in `tests/target/`.
- Framework: use what the project/platform already uses (Zephyr ztest + twister, Unity for ESP-IDF/PlatformIO, pytest where the project uses it). Otherwise GoogleTest/GoogleMock (also for C code through `extern "C"`). Don't mix frameworks without a reason.
- Style: one behavior per test, small, deterministic, independent; behavior-describing names; fake clock instead of sleeps; assert observable behavior; mocks must mirror real hardware semantics, and simplifications are reported.
- Cover boundaries, error paths, every state transition (including illegal ones), wraparound, init/deinit and cleanup, malformed input; concurrency stress under TSan; fuzz harnesses for parsers; failing regression test before a bug fix.
- Sanitizers on host: ASan/UBSan (TSan separately). GoogleTest needs a C++ runtime, so on small MCUs use the platform's light runner (ztest, Unity) for target runs. Don't modify production code for testability except minimal, explicitly stated seams.

### 2.4 Review
- Read-only. Scope: named files, else the current diff.
- Bugs/common mistakes: undefined behavior, logic and tick-wraparound errors, leaks, ISR/`volatile`/race errors, register mistakes, error handling, state machines.
- Security: trace untrusted input from entry points to sinks; memory safety, integer overflow, parsing, crypto and secrets, secure boot/OTA, debug interfaces, ISR/RTOS hazards.
- Obsolete code: deprecated language/libc/vendor APIs, dead code (verified against the build graph, vector tables, linker scripts, callback tables), stale workarounds, EOL dependencies.
- Findings ordered by severity, each with confidence, `file:line`, concrete failing scenario, and a fix; list assumptions and what was not reviewed. Concurrency: map contexts and shared state, then check races, locking/deadlocks, memory ordering, ISR handoff, lifetimes. Tags: `[BUG]`, `[CONC]`, `[SEC]`, `[OBSOLETE]`, plus a separate `[BEST-PRACTICE]` suggestion list.

---

## 3. Role prompts for tools without agent/skill support
Paste one as the system/role prompt, followed by the relevant 2.x rules.
- **Writer:** "You are a senior embedded C/C++ engineer. Follow the project's conventions. Make minimal, small changes; thread-safe objects when concurrency is involved; comment only when necessary. Build and test with the project's commands and report what you ran."
- **Test engineer:** "You are an embedded C/C++ test engineer. Put tests under `tests/`, cover the changed and affected code, make tests run on host and hardware through a mockable HAL, use the project's test framework (GoogleTest if none). Never touch hardware unless asked."
- **Reviewer:** "You are a read-only senior embedded C/C++ reviewer. Report bugs, security risks and obsolete code ordered by severity with file:line, scenario, fix, and confidence."
- **Security auditor:** "You are a read-only embedded security auditor. Map the attack surface, trace untrusted input to sinks, and report exploitable issues with severity, confidence and fix."

---

## 4. Project-specific template
Copy this block into the project's `CLAUDE.md`, fill the placeholders from the repo, and delete lines that don't apply.

```markdown
# <PROJECT NAME>

## Overview
<one or two lines: what the firmware does>

## Target
- MCU / SoC / board: <...>
- Architecture and toolchain: <e.g. arm-none-eabi-gcc 13, language standard C11 / C++17>
- RTOS / framework / SDK: <e.g. Zephyr x.y, FreeRTOS, ESP-IDF, bare metal>
- Memory constraints: <flash/RAM, heap policy: no heap after init / allowed>

## Build
- Build: `<command>`
- Flash (only on explicit user request): `<command>`
- Lint / static analysis: `<command>`

## Tests
- Framework: <ztest / Unity / GoogleTest / pytest>
- Host: `<command>`        (tests under `tests/`, mocks in `tests/mocks/`)
- Target / emulator: `<command>`  (hardware-only tests in `tests/target/`)
- Hardware availability: <always / bench only / none>

## Layout
- `<dir>`: <purpose>   # HAL, drivers, app logic, third-party, generated code (do not edit)

## Conventions
- Coding standard: <MISRA / CERT / in-house / none>
- Naming and formatting: <rules or formatter command>
- Error handling: <return codes / errno / exceptions disabled>
- Logging: <API and rules, forbidden in ISR>
- Threading model: <tasks, ISRs, shared resources, locking primitives in use>

## Rules for AI agents
- Follow the generic rules from AIAgentUsecaseHelper.md section 2 (small changes, thread-safe objects, minimal comments, tests under `tests/`, host + HW portability).
- Never edit: <vendor/generated/third-party dirs>.
- Never flash or touch hardware unless asked.
- Workflow: write code -> write tests -> review (`embedded-code-reviewer`; `embedded-security-auditor` for <security-sensitive areas>).

## Security context
- Attack surface: <interfaces and protocols>
- Threat model: <remote / local / physical>
- Secrets handling: <where keys live, what must never be logged>

## Known pitfalls
- <errata, quirks, timing constraints, things that look wrong but are intentional>
```
