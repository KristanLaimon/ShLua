# Luash Lua 5.1 Roadmap

## Completed work: Phases 0–3

- [x] Phase 0: create `TODO.md` and `PROGRESS.md`.
- [x] Phase 1: align primitive/operator lexing with Lua 5.1.
- [x] Phase 1: complete expression, declaration, assignment, and base AST parsing.
- [x] Phase 1: add focused lexer/parser coverage.
- [x] Phase 2: parse and lower `if`/`elseif`/`else`, `while`, and `repeat`/`until`.
- [x] Phase 2: parse and lower numeric `for` with one-time control-expression evaluation.
- [x] Phase 2: parse and lower generic `for` for `pairs`/`ipairs`.
- [x] Phase 2: parse and lower loop-local `break`.
- [x] Phase 2: execute generated loop/control-flow fixtures on installed shells.
- [x] Phase 3: complete named and anonymous function parsing/calls.
- [x] Phase 3: resolve lexical local/global bindings and block scope.
- [x] Phase 3: lower anonymous functions with captured lexical values for Bash and PowerShell.
- [x] Phase 3: execute generated function/closure fixtures on installed shells.
- [x] Update compatibility and architecture documentation for the Phase 0–3 subset and known limits.
- [x] Run `lua run_build.lua`, `lua run_tests.lua`, and `lua run_check.lua` successfully.

## Later phases

- [ ] Phase 4: Bash math and string standard-library support.
- [ ] Phase 5: PowerShell math and string standard-library support.
- [ ] Phase 6: OS, IO, and table libraries for both targets.
- [ ] Phase 7: standard-library dependency analysis and injection.
- [ ] Phase 8: bundling and full `hard_test.lua` end-to-end validation.

## Next session: Phase 4

- Read `TODO.md`, `PROGRESS.md`, and the Phase 4 library-related Lua 5.1 manual sections.
- Define the dependency-free Bash standard-library module contract under `src/stdlib/bash/`.
- Implement and execute focused Bash math/string cases before expanding `hard_test.lua` coverage.
- Add dependency-free script cases as `tests/scripts/NN_<testName>.test.lua`, ordered from simplest to most complex.
