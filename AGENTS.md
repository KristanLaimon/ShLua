# AGENTS.md - Luash Transpiler Project Context

## Project Overview
**Luash** is a Lua-to-shell transpiler that converts Lua source code into **Bash** (`.sh`) and **PowerShell** (`.ps1`) scripts. It uses a modular compiler architecture with Lexer → Parser → Transpiler pipeline.

## Stack & Requirements
- **Language**: Lua 5.1 compatible (also runs on LuaJIT)
- **No external dependencies** - no LuaRocks, no package managers
- **Standard library only** - uses only Lua 5.1 standard library (`io`, `string`, `table`, `os`, `math`, `debug`, `package`, `coroutine`)
- **Entry point**: `main.lua`
- **Testing**: Built-in `Lust.lua` test framework in `tests/Lust.lua`

## Architecture (SRP + Strategy Pattern + IoC)

```
Input File → CLI → Lexer → Parser → Lua AST → [Bash Transpiler / PS1 Transpiler] → Serializer → Output Files
```

### Core Modules
| File | Responsibility |
|------|----------------|
| `main.lua` | Composition root - registers transpilers, orchestrates pipeline |
| `src/cli.lua` | CLI argument parsing, file I/O, help text |
| `src/lexer.lua` | Lua 5.4 syntax tokenizer (keywords, strings, numbers, operators, comments) |
| `src/parser.lua` | Recursive descent parser producing Lua AST (Program, FunctionDecl, IfStmt, LocalVarDecl, AssignmentStmt, ReturnStmt, CallExpr, BinaryExpr, Identifier, Literal) |
| `src/ITranspiler.lua` | Interface contract validator for transpiler modules |
| `src/bash_transpiler.lua` | Bash 3.2+ target: Lua AST → Bash AST → `.sh` script |
| `src/ps1_transpiler.lua` | PowerShell 3.0+ target: Lua AST → PS1 AST → `.ps1` script |

### Transpiler Interface Contract (`src/ITranspiler.lua`)
Every transpiler must implement:
- `name` (string): e.g., `"bash"`, `"ps1"`
- `extension` (string): e.g., `".sh"`, `".ps1"`
- `new()` → instance
- `translate(luaAST)` → targetAST
- `Serializer.serialize(targetAST)` → string

## Supported Lua Subset (AST Nodes)
- **Program**: `{type="Program", body={...}}`
- **FunctionDecl**: `{type="FunctionDecl", name, params, body, isLocal}`
- **IfStmt**: `{type="IfStmt", condition, body}`
- **LocalVarDecl**: `{type="LocalVarDecl", name, init}`
- **AssignmentStmt**: `{type="AssignmentStmt", name, init}`
- **ReturnStmt**: `{type="ReturnStmt", value}`
- **ExprStmt**: `{type="ExprStmt", expr}`
- **CallExpr**: `{type="CallExpr", callee, args}`
- **BinaryExpr**: `{type="BinaryExpr", operator, left, right}`
- **Identifier**: `{type="Identifier", name}`
- **Literal**: `{type="Literal", value}` (number, string, boolean)

## CLI Usage
```bash
lua main.lua -i <input.lua> [-o <output>] [-t bash|ps1|all] [-v] [-a]
```
- `-i, --input`: Required input Lua file
- `-o, --output`: Output base path (extensions auto-appended for `all`)
- `-t, --target`: `bash`, `ps1`, or `all` (default: `all`)
- `-v, --verbose`: Print pipeline trace
- `-a, --dump-ast`: Print Lua AST and exit

## Testing
- Framework: `tests/Lust.lua` (zero-dependency, injects globals via `lust.injectGlobals()`)
- Test files: `tests/*.test.lua`, `tests/bash/*.test.lua`, `tests/powershell/*.test.lua`
- Run: `lua tests/<testfile>.test.lua`

## Key Conventions
- Lua 5.1 syntax only (no `goto`, no `::label::`, no UTF-8 library, no `table.unpack` - use `unpack`)
- Modules use `local M = {}; M.__index = M; function M.new() return setmetatable({}, M) end`
- No external deps - all code self-contained
- Run from repo root: `lua main.lua ...`

## Target Compatibility
- **Bash**: 3.2+ (POSIX `[ ... ]`, `name() { ... }`, `#!/usr/bin/env bash`)
- **PowerShell**: 3.0+ / Core 6+ (`param()`, `-eq/-ne/-lt`, `$true/$false`)

## Linting & Formatting
- **StyLua** (`stylua.toml`): 120 col width, 4-space indent, double quotes, Lua 5.1 target
- **Luacheck** (`.luacheckrc`): Lua 5.1 std, ignores unused args in callbacks (code 212/213), allows Lust globals
- **EditorConfig** (`.editorconfig`): UTF-8, LF, 4-space indent, 120 max line length, trim trailing whitespace

### Config Files
| File | Purpose |
|------|---------|
| `stylua.toml` | Formatting rules (column_width=120, indent=4, quote_style=AutoPreferDouble) |
| `.luacheckrc` | Static analysis (std=lua51, globals for Lust, exclude Lust.lua) |
| `.editorconfig` | Editor consistency (indent=4, eol=lf, charset=utf-8) |

### Commands
```bash
# Format code
stylua .

# Lint code
luacheck .

# Run tests
lua tests/<testfile>.test.lua
```

## Required Validation Before Completion

Run these commands from the repository root and do not report success unless all three are green:

```bash
lua run_build.lua  # syntax-checks sources and creates dist/luash.lua
lua run_tests.lua  # runs unit, complex, coroutine, integration, and dist tests
lua run_check.lua  # runs luac -p, StyLua --check, Luacheck, and dist smoke checks
```

- `dist/luash.lua` must stay dependency-free and usable both as a CLI and through `require("luash")`.
- Keep source syntax Lua 5.1 compatible. `run_check.lua` combines `luac -p`, StyLua's `Lua51` parser, and Luacheck's
  `lua51` standard; use an actual Lua 5.1 runtime too when one is available.
- Generated Bash and PowerShell must be tested by execution when their interpreters are installed, not only by string
  snapshots.

## Alpha Coroutine Contract

- Supported source calls are `coroutine.create(namedFunction)`, `coroutine.resume(handle)`, and
  `coroutine.yield(value)`.
- Create and resume calls are top-level-only in alpha.
- A worker has no parameters and contains only sequential yield calls followed by at most one final return.
- Resume exposes at most two values: success and one yielded/returned value. Each handle owns independent state.
- Full Lua scheduling, resume arguments, anonymous workers, `wrap`, `status`, and arbitrary control flow are not alpha
  features. Reject them clearly instead of silently changing their meaning.

## Brain Notes

- Store newly discovered implementation quirks as very small Markdown thoughts under `specs/brain/`.
- Do not read specification history by default. Consult an existing brain note only when a concrete quirk blocks the
  current task or when investigating a related regression.
- Read broader historical specs only when absolutely necessary to resolve missing design context.
