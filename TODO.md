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
- [x] Emit coroutine, callable-dispatch, and Bash arithmetic runtime fragments only when source lowering needs them.

## Completed work: Phases 4–8

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

## Completed Phase 6 table work

- [x] Parse sequence/keyed table constructors, indexing, field access, and `nil` deletion with Lua 5.1 semantics.
- [x] Define cross-target mutable table representations that preserve identity and typed numeric/string keys.
- [x] Implement `table.concat`, `table.insert`, `table.maxn`, `table.remove`, and `table.sort` for both targets.
- [x] Extend generic `pairs`/`ipairs` lowering to the shared table representation.
- [x] Decide the next alpha boundary for file handles, Lua string patterns/iterators, and multi-return library APIs;
      current calls reject clearly.
- [x] Execute construction, aliasing, function-return, mutation, sorting, nesting, and iteration fixtures on both shells.
- [x] Run `lua run_build.lua`, `lua run_tests.lua`, and `lua run_check.lua` successfully.

## Next session: post-roadmap maintenance

- Treat Phases 0–8 as complete for the documented alpha subset.
- Keep file handles, Lua patterns/string iterators, general multiple returns, methods/metatables, and dynamically typed
  Bash keys crossing untyped function parameters as explicit follow-up boundaries.
- Add a numbered real-shell fixture for future target behavior changes and rerun all three release gates.
