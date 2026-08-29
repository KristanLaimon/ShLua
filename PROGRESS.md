# Luash Implementation Progress

## Current stage

Phases 0–3 are complete. Phase 4 (Bash math/string standard library) is next.

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

`hard_test.lua` also uses table values and the `io`, `os`, `string`, and base libraries. Phases 0–3 established the
syntax, control-flow, function, and closure foundation; those library calls remain the work of phases 4–7.

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

## Validation state

- `hard_test.lua` parses completely, including its generic/numeric loops and returned anonymous function.
- Generated Phase 1–3 fixtures execute successfully under installed Bash and Windows PowerShell, including lexical
  shadowing, all new loop forms used by the fixture, anonymous/named captures, and ordinary recursion.
- `lua run_build.lua`: passed.
- `lua run_tests.lua`: 11 test files passed.
- `lua run_check.lua`: build, `luac -p`, StyLua, Luacheck, bundled CLI, and bundled API checks passed.
- No separate Lua 5.1 or LuaJIT executable was installed, so validation used the configured `lua` runtime plus the
  repository's Lua51 StyLua and Luacheck checks.
