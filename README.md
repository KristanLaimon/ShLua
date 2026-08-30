<p align="center">
  <img src=".github/shlua_icon.png" alt="ShLua logo" width="250">
  <br>
  <strong>ShLua</strong>
  <br>
  <span style="display:block;font-size:1.25rem;">Write shell scripts with the elegance and power of Lua.</span>
  <br>
  <em>"You know Lua? You already know bash/powershell then!" &mdash; Nobody</em>
  <br><br>
  <a href="https://github.com/KristanLaimon/ShLua/releases/latest"><img src="https://img.shields.io/github/v/release/KristanLaimon/ShLua?color=blue&style=flat-square" alt="Latest Release"></a>
<!--
  <a href="https://github.com/KristanLaimon/ShLua/releases"><img src="https://img.shields.io/github/downloads/KristanLaimon/ShLua/total?color=brightgreen&style=flat-square" alt="Downloads"></a>
-->
  <a href="LICENSE"><img src="https://img.shields.io/github/license/KristanLaimon/ShLua?color=informational&style=flat-square" alt="MIT License"></a>
<!--
  <a href="https://github.com/KristanLaimon/ShLua/stargazers"><img src="https://img.shields.io/github/stars/KristanLaimon/ShLua?style=flat-square" alt="GitHub Stars"></a>
-->
  <a href="https://github.com/sponsors/KristanLaimon"><img src="https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=github&style=flat-square" alt="Sponsor on GitHub"></a>
</p>

---

**ShLua** lets you write your script logic once in clean Lua and automatically transpile it to native, zero-dependency **Bash** and **PowerShell** scripts. No new syntax or DSL to learn, no forcing other script-interpreted runtimes onto your users—just fast, cross-platform scripts that run out-of-the-box in any terminal or CI pipeline.

---

## ✨ Features

- 🔄 **Lua to Shell Transpilation**: Write maintainable Lua scripts and transpile them to native shell scripts (Bash / PowerShell).
- ⚡ **Portable CLI**: Run the bundled Lua CLI file or a standalone Windows or Linux executable.
- 📦 **No extra setup required**: Easy installation and execution across platforms, no additional/external dependencies. Just
download and use. 


---

## 📦 Installing

Go to [releases](https://github.com/KristanLaimon/ShLua/releases/latest), then you can download the following formats.

- `shlua.lua` — dependency-free Lua 5.1 compatible library and usable as CLI.
- `shlua.exe` — standalone Windows x64 CLI executable.
- `shlua` — standalone Linux x64 CLI executable.

---

## 🚀 Usage

### As a standalone CLI 


First check  [Installing instructions](## 📦 Installing), then run `--help` with the Lua distribution, Windows executable, or Linux executable:

```bash
# Used as a CLI. You need lua >= 5.1 installed in your PATH env variable.
lua shlua.lua --help
```

```bash
# Windows
./luash_win_x64.exe --help
```

```bash
# Linux-Based OS
./luash --help

```

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


## As a Library (Support for >= lua 5.1)
```lua
-- Your custom lua script...
local ShLua = require("shlua")

local source = [[
local function greet(name)
    return "Hello, " .. name
end

print(greet("Lua"))
]] -- Or reading from another .lua file in CWD...

-- Transpiling (In memory)
local bash = ShLua.transpile(source, "bash")
local powershell = ShLua.compile(source, "ps1")
local both = ShLua.transpile(source, "all")

-- Transpiling (To output file!) Bash
local bashFile = assert(io.open("greet.sh", "w"))
bashFile:write(bash)
bashFile:close()

-- Transpiling (To output file!) Powershell
local ps1File = assert(io.open("greet.ps1", "w"))
ps1File:write(both.ps1) -- equivalent to `powershell`
ps1File:close()
```

---

## Compatibility

ShLua accepts Lua 5.1 syntax and transpiles to Bash 3.2+ and PowerShell 3.0+ (including PowerShell Core 6+).

---

## 🚧 Limitations

> 🚧 Still in early development, conceptual-only so far.

`require()` in the Lua source being transpiled is not supported yet. The `require("shlua")` call
in the library example above only loads ShLua into the host Lua runtime.

Not whole 5.1 stdlib ported yet to bash and ps1. Working on that.

---

## ❓ Why?

While tweaking my [nvim-config](https://github.com/KristanLaimon/Nvim-Config), I found myself repeating a tedious task: writing separate helper scripts in **Bash** and **PowerShell** for projects like [PanelsPlus](https://github.com/KristanLaimon/PanelsPlus) so contributors could build and set things up effortlessly on any OS without needing a deep dive into the repo.

So I thought:

> *Lua is simple, expressive, and lightweight—why shouldn't our build, CI, and helper scripts be as well?*

That highlighted a few common pain points:
- **Bash & PowerShell syntaxes are wildly different.** Learning both completely and keeping their logic manually in sync is error-prone.
- **Relying on AI gets tedious.** Prompting AI to translate script logic back and forth every time you make a change wastes time and tokens *(unless you're a token-maxxer, of course)*.
- **Python or Node.js scripts add unnecessary bloat for non-related projects.** Forcing contributors or CI/CD pipelines to install Node.js, Bun, or Python *just* to run a setup script—especially on projects that are possibly unrelated to JS or Python—is an annoying dependency lock-in, this applies for any other language.

The purpose is not a drop-in replacements for already stablished-mature building programs. Just provide an alternative for your multi-OS scripting, `a simpler one`.

## But, I already use ***** tool for building. Should I replace it with this?
 **Makefiles, `package.json` scripts, python, or anything you use are fine if you're already using them.** 
But they're tied down to their specific ecosystems. Of course, its natural to use `package.json` in js/ts projects or `Make` in C/C++ projects, (etc...), but what if you need your scripts outside of that ecosystem?, maybe for easily installation, faster CI actions pipelines...

This aims for projects that:

- Their build system lang is not related to the language of the project itself.
- Want create multi-platform native scripts (sh and ps1) without having to learn those 2 and maintain them separately. 
- Want curious git cloners that just want to clone-build fast without needing extra-effort. (Improving your proyect for possible new contributors)
- Want to optimize their CI, so they can run all the needed scripts without needint to install a whole runtime or binary just to run lint, build, formatting (& more) scripts?
