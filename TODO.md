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

## Completed work: Phases 4, 5, 7, and the Phase 8 fixture

- [x] Phase 4: add Bash math/string strategy modules and scalar helpers.
- [x] Phase 4: execute generated Bash math/string cases under Git-for-Windows Bash.
- [x] Phase 5: add PowerShell math/string strategy modules using PowerShell/.NET primitives.
- [x] Phase 5: execute generated PowerShell math/string cases under Windows PowerShell.
- [x] Phase 6: add Bash and PowerShell base, IO, OS, and table module contracts.
- [x] Phase 6: implement scalar base conversions, stream IO, and portable OS helpers used by the supported subset.
- [x] Phase 7: analyze nested AST calls/constants and inject only referenced target-library modules.
- [x] Phase 8: embed selected helper source into single generated scripts and the standalone `dist/luash.lua` compiler.
- [x] Phase 8: transpile and execute the original `hard_test.lua` on both installed target shells.
- [x] Fix value-returning `and`/`or`, PowerShell string concatenation, and Bash decimal arithmetic exposed by the fixture.
- [x] Make Windows tests find Git Bash outside `PATH` and distinguish launch failures from missing interpreters.

## Remaining Phase 6 work

- [ ] Parse sequence/keyed table constructors, indexing, and field access with Lua 5.1 semantics.
- [ ] Define a cross-target table value representation that preserves numeric and string keys.
- [ ] Implement `table.concat`, `table.insert`, `table.maxn`, `table.remove`, and `table.sort` for both targets.
- [ ] Extend generic `pairs`/`ipairs` lowering to the shared table representation.
- [ ] Decide the next alpha boundary for file handles, Lua string patterns/iterators, and multi-return library APIs;
      current calls reject clearly.

## Next session: Phase 6 tables

- Read the Lua 5.1 table-constructor/indexing and table-library manual sections.
- Add parser/resolver fixtures for sequence and keyed table values before selecting the shell encoding.
- Preserve one-time evaluation, mutable identity, 1-based indices, and `nil` deletion semantics in the design.
- Execute generated mutation/iteration cases on both installed shells, then rerun all three release gates.
