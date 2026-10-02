---
name: embedded-test-writing
description: Writing and running tests for C/C++ embedded code, on the host machine first and on target hardware (or emulator) second - framework detection (Zephyr ztest/twister, Unity, GoogleTest, pytest), HAL seams and fakes, fuzz and sanitizer runs. Use when adding, fixing or extending tests for C/C++ firmware.
---

# Embedded C/C++ Test Writing

Project-agnostic. Goal: the same logic is testable on the dev machine (fast loop) and, where it matters, on real hardware or an emulator.

## 0. Non-negotiables
- All tests live under the project's `tests/` subdirectory (create it if missing; follow its existing sub-layout). Never place tests next to production sources.
- Tests must cover all aspects of the changed code AND the affected area: the changed units, their direct callers/callees, and anything sharing state, interfaces, or hardware resources with them. Derive the affected area from the diff plus a reference search; list it in the report.
- The same test sources must run on the local machine and on hardware/emulator with minimal changes. Only the build/runner layer and the HAL implementation (mock on host, real on target) may differ. Test bodies must not contain `#ifdef HOST`/`#ifdef TARGET` branches.

## 1. Framework selection
Use what the project already uses. Detect from build files, existing tests, CI config, `prj.conf`, `CMakeLists.txt`, `platformio.ini`, `Makefile`, `conftest.py`.
Order of preference when nothing is set up:
1. Platform-native framework if the platform has one:
   - Zephyr: ztest, run with `twister` (native_sim on host, board or QEMU/Renode for target).
   - ESP-IDF: Unity (built in); PlatformIO: its Unity integration; Mbed: its greentea/utest; FreeRTOS projects: whatever the repo already uses.
   - Python-driven tests (pytest) when the project already has them, e.g. HIL scripts, serial/protocol checks, or when testing via a host tool.
2. Otherwise **GoogleTest (+ GoogleMock)**, including for C code (`extern "C"` wrappers; tests themselves are C++).
Never mix in a second framework without saying why.

## 2. Two execution targets
**Host (default loop)**
- Build the hardware-independent code with the host compiler, link against fakes/mocks of the HAL. Fast, runs in CI and locally.
- Run under sanitizers when available: `-fsanitize=address,undefined`; use TSan separately for threaded code (not combined with ASan).
- Beware host/target differences: word size, endianness, alignment, `int` width, struct packing, floating point, compiler. Keep fixed-width types and assert `sizeof` of wire structs in tests.

**Target (HW or emulator)**
- GoogleTest/GoogleMock need a C++ runtime, heap and often exceptions/RTTI, so they usually run on host, Linux-class targets, or capable emulators, not on small MCUs. For MCU targets, run the same test logic through the platform's light runner (ztest, Unity) or keep tests in a framework-neutral form; say which applies.
- Reuse the same test sources where possible; only the build/flash/runner layer differs (CMake toolchain file, twister platform, PlatformIO env, ctest label).
- Reserve target tests for what host cannot prove: timing, interrupts, DMA, peripherals, real memory/stack limits, RTOS behavior, hardware errata.
- Prefer an emulator (QEMU, Renode, native_sim) before a physical board when it covers the case. Results come back over UART/semihosting/RTT or the framework's runner; keep output machine-readable.
- Tests that need a physical rig must be clearly separated (label/tag/directory) so the host suite never depends on hardware.
- Never flash or touch hardware without the user's explicit instruction; if hardware is unavailable, write the tests, run the host part, and say the target part was not run.

## 3. Making code testable
- Find the seam: the smallest interface between logic and hardware (HAL function table, link-time substitution of a driver source, function-pointer injection, template/policy parameter in C++). Prefer link-time substitution for C, interfaces for C++.
- Inject time (fake clock), randomness and I/O; no real sleeps, no wall-clock dependence.
- If production code needs a change for testability, make it minimal, state it explicitly, and keep behavior identical. Do not otherwise modify production code.
- Don't mock what you own and can use directly (pure functions, small value types).

## 4. What to test
- Normal path, boundaries (0, 1, max, max+1), empty/full buffers, invalid and malformed input, every error return, every state-machine transition and illegal event/state, timeout paths.
- Wraparound of counters/ticks, integer edge values, endianness for wire formats.
- Resource handling: init/deinit, repeated init, failure midway (cleanup), no leaks (ASan/LSan on host).
- Threaded code: deterministic tests for logic; separate stress tests (many threads, many iterations) under TSan; test ISR-to-task handoff via fakes that trigger the handler at controlled points.
- Security-relevant parsers: malformed/oversized/truncated inputs; add a fuzz harness (libFuzzer/AFL++) taking a byte buffer when the parser is a good fit.
- Regression: when fixing a bug, write the failing test first and confirm it fails for the right reason.

## 5. Test style
- One behavior per test, small and independent, no order dependence, deterministic.
- Names state behavior: `Parser_RejectsLengthBeyondBuffer`.
- Arrange/act/assert with minimal setup; shared fixtures only when they reduce noise.
- Assert on observable behavior, not implementation details; avoid over-specifying mock call order unless order is the requirement.
- No comments beyond what is necessary; no commented-out tests; no disabled tests without a reason.
- Coverage (gcov/llvm-cov) is for finding untested branches, not a target to game.

## 6. Workflow
1. Detect framework, build system, existing test layout and naming; follow them.
2. Identify the changed code (diff or named files) and the affected area (callers, callees, shared state/resources); identify the seams. State the coverage plan before writing.
3. Write tests in small increments; build and run after each step.
4. Run the host suite (with sanitizers if available) and report exact commands and results. Run emulator tests if the tooling exists and the project defines them; run tests on physical hardware only when the user explicitly asks.
5. Report: tests added (paths under `tests/`), the changed and affected code they cover, what remains untested, any production changes for testability, and what was not run.

## 7. Portable tests: one test source, two backends
- Production code talks to hardware only through a HAL interface (header). Tests talk to production code only through its public API.
- Provide two implementations of that HAL interface: the real one (target build) and a mock/fake (host build). Select by build configuration (CMake option/toolchain, twister platform, PlatformIO env, Makefile target), not by `#ifdef` in tests.
- Fakes live in `tests/mocks/` (or `tests/fakes/`); keep them small, behavior-faithful (e.g. a fake UART with a TX capture buffer and injectable RX bytes, a fake clock advanced by the test, a fake GPIO/I2C/SPI with scripted responses and error injection), and reusable across tests.
- Test bodies are written against the HAL-level behavior, so they stay valid on both backends. Where a test can only be meaningful with real hardware (timing accuracy, electrical behavior), put it in `tests/target/` and register it only for the target build; everything else must be host-runnable.
- Tests that pass only against a mock prove little: keep mock behavior aligned with real hardware semantics (read-to-clear, busy flags, error modes) and say in the report where the mock simplifies reality.
- Hardware-only assertions go through a small helper (e.g. tolerance windows for timing) so the same test can run with exact values on host and tolerances on target.

## 8. Layout defaults (extend the project's layout; only create what's missing)
```
tests/
  unit/        tests of pure logic and modules, portable host/target
  mocks/       HAL mocks/fakes used by host builds
  fuzz/        fuzz harnesses
  target/      tests that need real hardware or emulator
  CMakeLists.txt (or the project's build equivalent), with a host target and a target option
```
With CMake: `enable_testing()`, GoogleTest via `FetchContent` pinned to a release tag (fetching needs network - say so, or use a vendored/system copy), `gtest_discover_tests`, and a build option selecting the mock vs real HAL.
