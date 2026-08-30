package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

describe("10 - hard_test end to end", function()
    it("transpiles and executes the original fixture on installed shells", function()
        local result = helper.compileAndRun("10_hard_test", readFile("tests/fixtures/hard_test.lua"))
        for _, target in ipairs({ "bash", "ps1" }) do
            local targetResult = result[target]
            expect(targetResult.code:find("require", 1, true) ~= nil).toBeFalsy()
            expect(targetResult.code:find("__shlua_io_write", 1, true) ~= nil).toBeTruthy()
            expect(targetResult.code:find("__shlua_os_clock", 1, true) ~= nil).toBeTruthy()
            if targetResult.executed then
                expect(targetResult.ok).toBeTruthy()
                expect(targetResult.output:find("Hello world\n1 2 3 ", 1, true) == 1).toBeTruthy()
                expect(targetResult.output:find("999 1000 Function Hola. Took: ", 1, true) ~= nil).toBeTruthy()
                expect(targetResult.output:sub(-9)).toBe(" seconds\n")
            end
        end
    end)
end)

lust.report()
