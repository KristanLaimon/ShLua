<p align="center">
  <img src=".github/luash_icon.png" alt="Luash logo" width="250">
  <br>
  <strong>Luash</strong>
  <br>
  <span style="display:block;font-size:1.25rem;">Write shell scripts with the elegance and power of Lua.</span>
  <br>
  <em>"You know Lua? You already know full bash/powershell then!" &mdash; Nobody</em>
  <br><br>
  <a href="https://github.com/KristanLaimon/Luash/releases/latest"><img src="https://img.shields.io/github/v/release/KristanLaimon/Luash?color=blue&style=flat-square" alt="Latest Release"></a>
  <a href="https://github.com/KristanLaimon/Luash/releases"><img src="https://img.shields.io/github/downloads/KristanLaimon/Luash/total?color=brightgreen&style=flat-square" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/KristanLaimon/Luash?color=informational&style=flat-square" alt="MIT License"></a>
  <a href="https://github.com/KristanLaimon/Luash/stargazers"><img src="https://img.shields.io/github/stars/KristanLaimon/Luash?style=flat-square" alt="GitHub Stars"></a>
  <a href="https://github.com/sponsors/KristanLaimon"><img src="https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=github&style=flat-square" alt="Sponsor on GitHub"></a>
</p>

---


**Luash** lets you write your script logic once in clean Lua and automatically transpile it to native, zero-dependency **Bash** and **PowerShell** scripts. No new syntax or DSL to learn, no forcing other script-interpreted runtimes onto your users—just fast, cross-platform scripts that run out-of-the-box in any terminal or CI pipeline.

> 🚧 Still in early development, conceptual-only so far.

---

## ✨ Features

- 🔄 **Lua to Shell Transpilation**: Write maintainable Lua scripts and transpile them to native shell scripts (Bash / PowerShell).
- ⚡ **Go-Powered CLI**: Fast, single binary multiplatform compiler with zero external runtime dependencies.
- 🔌 **Seamless Editor Support**: Native integrations for NVIM, VS Code, Visual Studio, and JetBrains.
- 📦 **No Setup Required**: Easy installation and execution across platforms.


> *Lua is simple, expressive, and lightweight—why shouldn't our build, CI, and helper scripts be as well?*

---

## 📦 Distributables

The goal for Luash is to provide seamless workflows across CLI tools and editors:

- 🛠️ **CLI Transpiler**: Standalone, multi-platform executable written in **Go** *(High Priority)*.
- 🌙 **Neovim Plugin**: Integration for **NVIM** *(High Priority)*.
- 🟦 **VS Code Extension**: IntelliSense & automatic transpilation for **Visual Studio Code** *(Medium Priority)*.
- 🟣 **Visual Studio Extension**: IntelliSense & automatic transpilation for **Visual Studio** *(Low Priority)*.
- 🧰 **JetBrains Plugin**: Integration for the **JetBrains IDE family** *(Low Priority)*.

---

## ❓ Why?

While tweaking my [nvim-config](https://github.com/KristanLaimon/Nvim-Config), I found myself repeating a tedious task: writing separate helper scripts in **Bash** and **PowerShell** for projects like [PanelsPlus](https://github.com/KristanLaimon/PanelsPlus) so contributors could build and set things up effortlessly on any OS without needing a deep dive into the repo.

That highlighted a few common pain points:
- **Bash & PowerShell syntaxes are wildly different.** Learning both completely and keeping their logic manually in sync is error-prone.
- **Relying on AI gets tedious.** Prompting AI to translate script logic back and forth every time you make a change wastes time and tokens *(unless you're a token-maxxer, of course)*.
- **Python or Node.js scripts add unnecessary bloat.** Forcing contributors or CI/CD pipelines to install Node.js, Bun, or Python *just* to run a setup script—especially on projects unrelated to JS or Python—is an annoying dependency lock-in.
- **Makefiles & `package.json` scripts are fine—if you're already using them.** But they're tied down to their specific ecosystems. If your project isn't using Node or Make, adding them just for helper scripts feels forced.
