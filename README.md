# Luash

Luash is a zero-runtime-dependency Lua-to-Bash and Lua-to-PowerShell transpiler. This repository currently ships an
alpha supporting basic scripts, named functions, conditionals, expressions, and a restricted generator-style
coroutine API.

```bash
lua run_build.lua
lua dist/luash.lua -i example.lua -o output/example -t all
```

The build produces one reusable file. It can also be loaded as a Lua module:

```lua
package.path = "dist/?.lua;" .. package.path
local luash = require("luash")

local bash = luash.transpile("print('hello')", "bash")
local powershell = luash.transpile("print('hello')", "ps1")
```

Quality commands:

```bash
lua run_build.lua
lua run_tests.lua
lua run_check.lua
```

See `spec/alpha.md` for the supported subset and coroutine limits. The included Lust test framework is derived from
<https://github.com/bjornbytes/lust>.
