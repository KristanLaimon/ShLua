# Luash Implementation Progress

## Current stage

Phases 0–5 and 7 are complete. The `hard_test.lua` Phase 8 fixture and helper bundling are complete. Phase 6 table
values/mutation remain the active stage; scalar base, IO, and OS support is already implemented.

## Starting state

- The compiler is a dependency-free Lexer -> Parser -> target transpiler -> Serializer pipeline and must remain Lua 5.1/LuaJIT compatible.
- The existing AST and both targets already support primitive literals, identifiers, unary/binary expressions, assignments, named functions, calls, returns, conditionals, and the restricted alpha coroutine contract.
- Existing staged work has begun parsing `FunctionExpr`, `NumericForStmt`, and `GenericForStmt`, and has begun Bash metadata collection, but target lowering is incomplete.
- `while`, `repeat`/`until`, `break`, and explicit block nodes are not implemented at this starting point.
- The staged string-escape lexer change follows Lua runtime values but requires the older lexer snapshot test to be updated.

## Specification decisions

- Lua 5.1 manual sections 2.3–2.6 are authoritative for phases 1–3.
- Numeric `for` control expressions and generic iterator expressions must be evaluated once before iteration.
- Numeric and generic loop variables are local to their loop.
- The scope of locals declared in a `repeat` body includes the `until` condition.
- Local declarations become visible after their initializer; local function declarations bind their name before resolving their body so recursion works.
- Bash output targets Bash 3.2+ and PowerShell output targets Windows PowerShell 3.0+/PowerShell Core 6+.
- Generated names beginning with `__luash_` remain reserved.

## Known later-phase boundary

Table constructors, indexing, mutable identity, and the `table` library still need a cross-target representation.
File handles, Lua string patterns/iterators, seeded random state, and library APIs requiring general multiple returns
are explicit errors rather than approximate translations.

## Phase 0–3 implementation summary

- Added `src/scope_resolver.lua` as a shared lexical-binding pass. It resolves local/global references, parameters,
  block locals, loop locals, recursive function names, and closure capture lists before either backend serializes.
- Aligned the lexer with Lua 5.1 keywords/operators (`goto` is an identifier), decoded short-string escapes, and made
  decimal/hexadecimal number scanning reject malformed exponents and hex literals.
- Extended the AST/parser with `FunctionExpr`, `WhileStmt`, `RepeatStmt`, `NumericForStmt`, `GenericForStmt`, `DoStmt`,
  and `BreakStmt`; local declarations and returns may omit values.
- Numeric-loop control expressions lower into generated temporaries so they execute once. Positive, negative, and zero
  step branch rules follow the Lua 5.1 manual model.
- Generic loops currently lower only `pairs(identifier)` and `ipairs(identifier)`. They snapshot the collection before
  iteration; source table constructors/indexing remain Phase 6 work.
- Both targets emit anonymous functions and named functions that read captured outer locals. Ordinary named recursion
  works. Recursive functions that also capture outer locals are rejected clearly.
- Bash closures use an encoded callable value and `__luash_call`; capture writes are rejected because Bash 3.2 cannot
  preserve shared mutable environments safely in the current value-return convention. PowerShell closure environments
  are hashtables. See `specs/brain/closure-capture.md`.
- Block locals receive reserved unique names when the target shell would otherwise leak or dynamically resolve them.
- Restored both positional CLI input and the existing `-i`/`--input` form.
- Updated architecture/compatibility docs and added parser, serializer, and real-shell execution coverage.
- Removed the old target-specific regression directories. Compiler suites remain directly under `tests/`; numbered
  dependency-free source-script cases live under `tests/scripts/`.

## Validation state

- `hard_test.lua` transpiles and executes completely on Git-for-Windows Bash and Windows PowerShell. Its generated
  scripts print `Hello world`, the sequence 1–1000, and `Function Hola. Took: … seconds`.
- Generated Phase 1–3 fixtures execute successfully under installed Bash and Windows PowerShell, including lexical
  shadowing, all new loop forms used by the fixture, anonymous/named captures, and ordinary recursion.
- `lua run_build.lua`: passed.
- `lua run_tests.lua`: 19 test files passed (8 compiler/integration suites and 11 numbered script cases).
- `lua run_check.lua`: build, `luac -p`, StyLua, Luacheck, bundled CLI, and bundled API checks passed.
- No separate Lua 5.1 or LuaJIT executable was installed, so validation used the configured `lua` runtime plus the
  repository's Lua51 StyLua and Luacheck checks.

## Phase 4–8 implementation summary

- Added target strategy modules under `src/stdlib/bash/` and `src/stdlib/powershell/` for base, math, string, IO, OS,
  and table namespaces. Supported scalar calls map to shell helpers; unsupported semantic categories carry precise
  compile-time reasons.
- Bash math and general source arithmetic use standard `awk` for decimal behavior. Numeric-loop counters intentionally
  remain Bash integer arithmetic. Bash string helpers combine built-ins with `awk`; selected OS calls use standard
  Unix commands only when referenced.
- PowerShell math/string helpers use .NET and stay compatible with Windows PowerShell 3-era APIs. Concatenation now
  casts operands to strings so a numeric left operand does not force numeric conversion.
- Implemented scalar `tonumber`, `tostring`, `type`, `io.write`/`flush`/line `read`, and common `os` calls for both
  targets. `os.clock` is elapsed wall time on both targets, not Lua process CPU time.
- Added `src/stdlib_analyzer.lua`. It walks all nested statements/expressions, detects base or dotted-library usage and
  constants, and selects only the referenced modules for target serialization.
- Fixed expression-form `and`/`or` to return operand values, which was required by `name = name or ""` in the fixture.
- Updated shell test discovery to find Scoop/Git-for-Windows Bash when it is not on `PATH`; fixed Windows `io.popen`
  quoting and stopped treating failed launches as skipped execution.
- Added focused script cases `08_bash_stdlib`, `09_powershell_stdlib`, and `10_hard_test`, plus analyzer coverage.

## Script test layout

- The former `tests/bash/` and `tests/powershell/` regression directories were removed.
- Existing compiler suites retain their original flat names under `tests/`.
- `tests/scripts/00_minimal.test.lua` through `07_complex.test.lua` exercise dependency-free generated programs in
  increasing complexity.
- `08_bash_stdlib` and `09_powershell_stdlib` execute target-specific math/string helpers; `10_hard_test` executes the
  original fixture on both installed targets and checks stable output boundaries around the nondeterministic duration.
- Script cases write generated `.sh` and `.ps1` files into `tests/scripts/`. `run_tests.lua` deletes the exact known
  artifacts after all cases run, including after ordinary test failures; `.gitignore` protects interrupted runs.
