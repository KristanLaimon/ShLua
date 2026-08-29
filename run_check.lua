#!/usr/bin/env lua

local FILES = {
    "main.lua",
    "run_build.lua",
    "run_check.lua",
    "run_tests.lua",
    "src/cli.lua",
    "src/lexer.lua",
    "src/parser.lua",
    "src/scope_resolver.lua",
    "src/ITranspiler.lua",
    "src/bash_transpiler.lua",
    "src/ps1_transpiler.lua",
    "src/luash.lua",
    "tests/lexer.test.lua",
    "tests/parser.test.lua",
    "tests/bash_transpiler.test.lua",
    "tests/ps1_transpiler.test.lua",
    "tests/coroutine.test.lua",
    "tests/integration.test.lua",
    "tests/dist.test.lua",
    "tests/script_test_helper.lua",
    "tests/scripts/00_minimal.test.lua",
    "tests/scripts/01_variables.test.lua",
    "tests/scripts/02_conditionals.test.lua",
    "tests/scripts/03_loops.test.lua",
    "tests/scripts/04_functions.test.lua",
    "tests/scripts/05_closures.test.lua",
    "tests/scripts/06_coroutines.test.lua",
    "tests/scripts/07_complex.test.lua",
}

local function runCommand(command)
    local handle = assert(io.popen(command .. " 2>&1"))
    local output = handle:read("*a")
    local success, _, code = handle:close()
    return success and (not code or code == 0), output
end

local function runCheck(name, command)
    io.write("Running " .. name .. "... ")
    local ok, output = runCommand(command)
    if ok then
        print("OK")
        return true
    end
    print("FAILED")
    io.write(output)
    if output:sub(-1) ~= "\n" then
        print()
    end
    return false
end

local function quotedFiles()
    local values = {}
    for _, path in ipairs(FILES) do
        table.insert(values, '"' .. path .. '"')
    end
    return table.concat(values, " ")
end

print("=== Luash Code Quality Checks ===")
local files = quotedFiles()
local allPassed = true
allPassed = runCheck("build + bundle syntax", "lua run_build.lua") and allPassed
allPassed = runCheck("Lua syntax (luac -p)", "luac -p " .. files .. ' "dist/luash.lua"') and allPassed
allPassed = runCheck("StyLua format", "stylua --check -- " .. files) and allPassed
allPassed = runCheck("Luacheck", "luacheck " .. files) and allPassed
allPassed = runCheck("bundled CLI", "lua dist/luash.lua --help") and allPassed
local apiCheck = "lua -e \"package.path='dist/?.lua'; local l=require('luash'); "
    .. "assert(type(l.transpile('print(1)','bash'))=='string')\""
allPassed = runCheck("bundled reusable API", apiCheck) and allPassed

print()
if allPassed then
    print("=== ALL CHECKS PASSED ===")
    os.exit(0)
end
print("=== SOME CHECKS FAILED ===")
os.exit(1)
