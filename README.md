<p align="center">
  <img src=".github/shlua_icon.png" alt="ShLua logo" width="250">
  <br>
  <strong>ShLua</strong>
  <br>
  <span style="display:block;font-size:1.25rem;">Write shell scripts with the elegance and power of Lua.</span>
  <br>
  <em>"You know Lua? You already know full bash/powershell then!" &mdash; Nobody</em>
  <br><br>
  <a href="https://github.com/KristanLaimon/ShLua/releases/latest"><img src="https://img.shields.io/github/v/release/KristanLaimon/ShLua?color=blue&style=flat-square" alt="Latest Release"></a>
  <a href="https://github.com/KristanLaimon/ShLua/releases"><img src="https://img.shields.io/github/downloads/KristanLaimon/ShLua/total?color=brightgreen&style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/KristanLaimon/ShLua?color=informational&style=flat-square" alt="MIT License"></a>
  <a href="https://github.com/KristanLaimon/ShLua/stargazers"><img src="https://img.shields.io/github/stars/KristanLaimon/ShLua?style=flat-square" alt="GitHub Stars"></a>
  <a href="https://github.com/sponsors/KristanLaimon"><img src="https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=github&style=flat-square" alt="Sponsor on GitHub"></a>
</p>

---


**ShLua** lets you write your script logic once in clean Lua and automatically transpile it to native, zero-dependency **Bash** and **PowerShell** scripts. No new syntax or DSL to learn, no forcing other script-interpreted runtimes onto your users—just fast, cross-platform scripts that run out-of-the-box in any terminal or CI pipeline.

> 🚧 Still in early development, conceptual-only so far.

---

## ✨ Features

- 🔄 **Lua to Shell Transpilation**: Write maintainable Lua scripts and transpile them to native shell scripts (Bash / PowerShell).
- ⚡ **Portable CLI**: Run the bundled Lua CLI or a standalone Windows or Linux executable.
- 🔌 **Seamless Editor Support**: Native integrations for NVIM, VS Code, Visual Studio, and JetBrains.
- 📦 **No Setup Required**: Easy installation and execution across platforms.


> *Lua is simple, expressive, and lightweight—why shouldn't our build, CI, and helper scripts be as well?*

---

## 📦 Distributables

The `dist/` directory contains the three current distribution artifacts:

- `shlua.lua` — dependency-free Lua library and CLI.
- `shlua.exe` — standalone Windows x64 CLI executable.
- `shlua` — standalone Linux x64 CLI executable.

---

## 🚀 Usage

### CLI

Run `--help` with the Lua distribution, Windows executable, or Linux executable:

```text
ShLua v0.1.0-alpha - Transpile Lua code to Bash, PowerShell, or both.

USAGE:
            lua main.lua <input.lua> [OPTIONS]
            lua main.lua -i <input.lua> [OPTIONS]

OPTIONS:
    -i, --input <file>     Path to input Lua script.
    -o, --output <file>    Base path for output files (Optional).
                           If target is 'all', target extensions (.sh/.ps1) are appended.
    -t, --target <target>  Target language: 'bash', 'ps1', or 'all' (Default: 'all').
    -a, --dump-ast         Print source Lua AST to stdout and exit.
    -v, --verbose          Print execution pipeline trace details.
    -h, --help             Show this help menu and exit.
```

From the `dist/` directory, the same arguments work with every CLI distribution:

```bash
# Lua CLI
lua ./shlua.lua ./script.lua -t all -o ./build/script

# Windows executable (PowerShell)
.\shlua.exe .\script.lua -t bash -o .\build\script

# Linux executable
./shlua ./script.lua -t ps1 -o ./build/script
```

`<input.lua>` may be supplied positionally or with `-i` / `--input`. `-o` / `--output` sets the output base path; when
the target is `all`, ShLua writes both `.sh` and `.ps1` files. `-t` / `--target` selects `bash`, `ps1`, or `all`
(the default). Use `-a` / `--dump-ast` to print the parsed Lua AST without generating output, `-v` / `--verbose` for
pipeline messages, and `-h` / `--help` to show the help text.

### Lua library

Load `dist/shlua.lua` as `shlua` and use `parse`, `transpile`, or its `compile` alias. `transpile` and `compile` accept
`"bash"`, `"ps1"`, or `"all"`; `"all"` returns a table with `bash` and `ps1` strings.

```lua
package.path = "./dist/?.lua;" .. package.path

local ShLua = require("shlua")

local source = [[
local function greet(name)
    return "Hello, " .. name
end

print(greet("Lua"))
]]

local ast = ShLua.parse(source)
assert(ast.type == "Program")

local bash = ShLua.transpile(source, "bash")
local powershell = ShLua.compile(source, "ps1")
local both = ShLua.transpile(source, "all")

local bashFile = assert(io.open("greet.sh", "w"))
bashFile:write(bash)
bashFile:close()

local ps1File = assert(io.open("greet.ps1", "w"))
ps1File:write(both.ps1) -- equivalent to `powershell`
ps1File:close()
```

---

## 🚧 Limitations

> 🚧 Still in early development, conceptual-only so far.

`require()` in the Lua source being transpiled is not supported yet and has not been tested. The `require("shlua")` call
in the library example above only loads ShLua into the host Lua runtime.

---

## ❓ Why?

While tweaking my [nvim-config](https://github.com/KristanLaimon/Nvim-Config), I found myself repeating a tedious task: writing separate helper scripts in **Bash** and **PowerShell** for projects like [PanelsPlus](https://github.com/KristanLaimon/PanelsPlus) so contributors could build and set things up effortlessly on any OS without needing a deep dive into the repo.

That highlighted a few common pain points:
- **Bash & PowerShell syntaxes are wildly different.** Learning both completely and keeping their logic manually in sync is error-prone.
- **Relying on AI gets tedious.** Prompting AI to translate script logic back and forth every time you make a change wastes time and tokens *(unless you're a token-maxxer, of course)*.
- **Python or Node.js scripts add unnecessary bloat.** Forcing contributors or CI/CD pipelines to install Node.js, Bun, or Python *just* to run a setup script—especially on projects unrelated to JS or Python—is an annoying dependency lock-in.
- **Makefiles & `package.json` scripts are fine—if you're already using them.** But they're tied down to their specific ecosystems. If your project isn't using Node or Make, adding them just for helper scripts feels forced.
