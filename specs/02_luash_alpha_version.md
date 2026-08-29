# Luash 0.1.0-alpha

Luash transpiles its documented Lua subset into Bash 3.2+ and PowerShell 3.0+ scripts. The alpha supports literals,
variables, arithmetic, concatenation, comparisons, logical and unary expressions, named functions, calls, returns,
and `if`/`elseif`/`else` blocks.

## Distribution

`lua run_build.lua` creates `dist/luash.lua`. That one file contains every compiler module and uses only the Lua
standard library.

```bash
lua dist/luash.lua -i input.lua -o output/script -t all
```

```lua
package.path = "dist/?.lua;" .. package.path
local luash = require("luash")
local bash = luash.transpile(source, "bash")
local both = luash.compile(source, "all") -- { bash = "...", ps1 = "..." }
```

## Coroutine subset

Alpha coroutines are deterministic generators. A named, parameterless worker may contain sequential
`coroutine.yield(value)` calls and one final `return value`. Create assigns independent state to each handle; resume
returns `success, value`; resuming after completion returns `false, "cannot resume dead coroutine"`. Create and resume
calls are restricted to the program's top level in alpha.

Anonymous workers, resume arguments, multiple yielded values, nested control flow inside workers, scheduling,
`coroutine.wrap`, and `coroutine.status` are intentionally rejected or unsupported.

## Release gate

`lua run_build.lua`, `lua run_tests.lua`, and `lua run_check.lua` must all pass. Integration tests execute generated
Bash and PowerShell when the interpreters are available; distribution tests load only `dist/luash.lua`.
