#!/usr/bin/env lua

local MODULES = {
    { name = "cli", path = "src/cli.lua" },
    { name = "lexer", path = "src/lexer.lua" },
    { name = "luabundler", path = "src/luabundler.lua" },
    { name = "parser", path = "src/parser.lua" },
    { name = "scope_resolver", path = "src/scope_resolver.lua" },
    { name = "stdlib_analyzer", path = "src/stdlib_analyzer.lua" },
    { name = "stdlib_selector", path = "src/stdlib_selector.lua" },
    { name = "ITranspiler", path = "src/ITranspiler.lua" },
    { name = "stdlib.bash.base", path = "src/stdlib/bash/base.lua" },
    { name = "stdlib.bash.io", path = "src/stdlib/bash/io.lua" },
    { name = "stdlib.bash.math", path = "src/stdlib/bash/math.lua" },
    { name = "stdlib.bash.os", path = "src/stdlib/bash/os.lua" },
    { name = "stdlib.bash.string", path = "src/stdlib/bash/string.lua" },
    { name = "stdlib.bash.table", path = "src/stdlib/bash/table.lua" },
    { name = "stdlib.powershell.base", path = "src/stdlib/powershell/base.lua" },
    { name = "stdlib.powershell.io", path = "src/stdlib/powershell/io.lua" },
    { name = "stdlib.powershell.math", path = "src/stdlib/powershell/math.lua" },
    { name = "stdlib.powershell.os", path = "src/stdlib/powershell/os.lua" },
    { name = "stdlib.powershell.string", path = "src/stdlib/powershell/string.lua" },
    { name = "stdlib.powershell.table", path = "src/stdlib/powershell/table.lua" },
    { name = "bash_transpiler", path = "src/bash_transpiler.lua" },
    { name = "ps1_transpiler", path = "src/ps1_transpiler.lua" },
    { name = "__shlua_core", path = "src/shlua.lua" },
}

local SOURCE_FILES = {
    "main.lua",
    "run_build.lua",
    "run_check.lua",
    "run_tests.lua",
    "src/cli.lua",
    "src/lexer.lua",
    "src/luabundler.lua",
    "src/parser.lua",
    "src/scope_resolver.lua",
    "src/stdlib_analyzer.lua",
    "src/stdlib_selector.lua",
    "src/ITranspiler.lua",
    "src/stdlib/bash/base.lua",
    "src/stdlib/bash/io.lua",
    "src/stdlib/bash/math.lua",
    "src/stdlib/bash/os.lua",
    "src/stdlib/bash/string.lua",
    "src/stdlib/bash/table.lua",
    "src/stdlib/powershell/base.lua",
    "src/stdlib/powershell/io.lua",
    "src/stdlib/powershell/math.lua",
    "src/stdlib/powershell/os.lua",
    "src/stdlib/powershell/string.lua",
    "src/stdlib/powershell/table.lua",
    "src/bash_transpiler.lua",
    "src/ps1_transpiler.lua",
    "src/shlua.lua",
}

-- Prebuilt Lua 5.1 SRLua runtimes are versioned with the repository so a build
-- never needs LuaInstaller, a C compiler, or network access. The footer widths
-- match the C `long` used by SRLua's glue utility for each target ABI.
local SRLUA_TARGETS = {
    {
        name = "Windows x64",
        runtime = "tools/srlua/windows/srlua515.exe",
        output = "dist/shlua.exe",
        footerLongBytes = 4,
        magic = "MZ",
    },
    {
        name = "Linux x64",
        runtime = "tools/srlua/linux/srlua515",
        output = "dist/shlua",
        footerLongBytes = 8,
        magic = "\127ELF",
        executable = true,
    },
}

local function readFile(path)
    local file, err = io.open(path, "rb")
    assert(file, "Build Error: cannot read " .. path .. ": " .. tostring(err))
    local content = file:read("*a")
    file:close()
    local normalized = content:gsub("\r\n", "\n")
    return normalized
end

local function readBinaryFile(path)
    local file, err = io.open(path, "rb")
    assert(file, "Build Error: cannot read " .. path .. ": " .. tostring(err))
    local content = file:read("*a")
    file:close()
    return content
end

local function writeFile(path, content)
    local file, err = io.open(path, "wb")
    assert(file, "Build Error: cannot write " .. path .. ": " .. tostring(err))
    file:write(content)
    file:close()
end

local function ensureDistDirectory()
    local separator = package.config:sub(1, 1)
    local command = separator == "\\" and 'if not exist "dist" mkdir "dist"' or 'mkdir -p "dist"'
    local ok = os.execute(command)
    assert(ok == true or ok == 0, "Build Error: could not create dist directory")
end

local function syntaxCheck(path)
    local chunk, err = loadfile(path)
    assert(chunk, "Syntax Error in " .. path .. ": " .. tostring(err))
end

local function encodeLittleEndian(value, byteCount)
    local bytes = {}
    for index = 1, byteCount do
        bytes[index] = string.char(value % 256)
        value = math.floor(value / 256)
    end
    assert(value == 0, "Build Error: SRLua payload is too large")
    return table.concat(bytes)
end

local function srluaPayload(bundle)
    local newlineIndex = assert(bundle:find("\n", 1, true), "Build Error: bundled Lua source has no first line")
    assert(bundle:sub(1, newlineIndex - 1) == "#!/usr/bin/env lua", "Build Error: bundled Lua shebang is missing")
    return bundle:sub(newlineIndex + 1)
end

local function packageSrlua(bundle)
    local payload = srluaPayload(bundle)
    for _, target in ipairs(SRLUA_TARGETS) do
        local runtime = readBinaryFile(target.runtime)
        assert(
            runtime:sub(1, #target.magic) == target.magic,
            "Build Error: invalid " .. target.name .. " SRLua runtime"
        )

        local footer = "%%glue:L"
            .. encodeLittleEndian(#runtime, target.footerLongBytes)
            .. encodeLittleEndian(#payload, target.footerLongBytes)
        writeFile(target.output, runtime .. payload .. footer)

        if target.executable and package.config:sub(1, 1) == "/" then
            local ok = os.execute('chmod +x "' .. target.output .. '"')
            assert(ok == true or ok == 0, "Build Error: could not mark " .. target.output .. " executable")
        end
    end
end

local function buildBundle()
    local chunks = {
        "#!/usr/bin/env lua\n",
        "-- Generated by run_build.lua. Do not edit this file directly.\n",
        "-- ShLua 0.1.0-alpha: dependency-free CLI and reusable module.\n\n",
    }
    for _, module in ipairs(MODULES) do
        table.insert(chunks, "package.preload[" .. string.format("%q", module.name) .. "] = function(...)\n")
        table.insert(chunks, readFile(module.path))
        table.insert(chunks, "\nend\n\n")
    end
    table.insert(
        chunks,
        [[local __shlua = require("__shlua_core")
local __loadedAs = ...
if type(__loadedAs) == "string" and __loadedAs:match("shlua$") and not __loadedAs:match("^%-") then
    return __shlua
end
local __exitCode = __shlua.main(arg or {})
if __exitCode ~= 0 then
    os.exit(__exitCode)
end
return __shlua
]]
    )
    ensureDistDirectory()
    local bundle = table.concat(chunks)
    writeFile("dist/shlua.lua", bundle)
    return bundle
end

print("=== ShLua Build ===")
for _, path in ipairs(SOURCE_FILES) do
    syntaxCheck(path)
end
local bundle = buildBundle()
syntaxCheck("dist/shlua.lua")
packageSrlua(bundle)

package.path = "src/?.lua;src/?/init.lua;" .. package.path
local ShLua = require("shlua")
local bash = ShLua.transpile("local x = 1 + 2\nprint(x)", "bash")
local ps1 = ShLua.transpile("local x = 1 + 2\nprint(x)", "ps1")
assert(bash:find("#!/usr/bin/env bash", 1, true) == 1, "Build Error: Bash smoke test failed")
assert(ps1:find("__shlua_print", 1, true), "Build Error: PowerShell smoke test failed")

print("Built dist/shlua.lua, dist/shlua.exe, and dist/shlua (standalone CLI artifacts)")
print("=== BUILD SUCCESSFUL ===")
