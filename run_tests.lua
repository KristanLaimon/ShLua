#!/usr/bin/env lua
-- ============================================================================
-- Test Runner: Executes all test files
-- File: run_tests.lua
-- ============================================================================

package.path = package.path .. ";src/?.lua;src/?/init.lua;tests/?.lua;tests/?/init.lua"

local function runTestFile(filepath)
    local filename = filepath:match("([^/\\]+)%.lua$")
    io.write("Running " .. filename .. "... ")

    -- Run in separate process to isolate globals
    local cmd = "lua " .. filepath .. " 2>&1"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success, _, code = handle:close()

    if success and code == 0 then
        print("PASS")
        return true, ""
    else
        print("FAIL")
        return false, result
    end
end

local scriptTestFiles = {
    "tests/scripts/00_minimal.test.lua",
    "tests/scripts/01_variables.test.lua",
    "tests/scripts/02_conditionals.test.lua",
    "tests/scripts/03_loops.test.lua",
    "tests/scripts/04_functions.test.lua",
    "tests/scripts/05_closures.test.lua",
    "tests/scripts/06_coroutines.test.lua",
    "tests/scripts/07_complex.test.lua",
    "tests/scripts/08_bash_stdlib.test.lua",
    "tests/scripts/09_powershell_stdlib.test.lua",
    "tests/scripts/10_hard_test.test.lua",
    "tests/scripts/11_tables.test.lua",
}

local testFiles = {
    "tests/lexer.test.lua",
    "tests/parser.test.lua",
    "tests/bash_transpiler.test.lua",
    "tests/ps1_transpiler.test.lua",
    "tests/coroutine.test.lua",
    "tests/integration.test.lua",
    "tests/stdlib_analyzer.test.lua",
    "tests/dist.test.lua",
}

for _, filepath in ipairs(scriptTestFiles) do
    table.insert(testFiles, filepath)
end

local function cleanupGeneratedScripts()
    for _, filepath in ipairs(scriptTestFiles) do
        local basePath = filepath:gsub("%.test%.lua$", "")
        os.remove(basePath .. ".sh")
        os.remove(basePath .. ".ps1")
    end
end

print("=== Luash Test Suite ===\n")

local passed = 0
local failed = 0
local failedTests = {}

for _, filepath in ipairs(testFiles) do
    local ok, output = runTestFile(filepath)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        table.insert(failedTests, { file = filepath, output = output })
    end
end

cleanupGeneratedScripts()

print()
print("=== Test Summary ===")
print("Passed: " .. passed)
print("Failed: " .. failed)
print("Total:  " .. (passed + failed))

if failed > 0 then
    print("\nFailed Tests:")
    for _, ft in ipairs(failedTests) do
        print("  " .. ft.file)
        print(ft.output)
    end
    os.exit(1)
else
    print("\n=== ALL TESTS PASSED ===")
    os.exit(0)
end
