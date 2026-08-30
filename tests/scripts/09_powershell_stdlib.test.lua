package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("09 - PowerShell math and string standard libraries", function()
    it("executes scalar math and string helpers", function()
        local result = helper.compileAndRunTarget(
            "09_powershell_stdlib",
            [[print(string.format("%.1f:%d", math.abs(-4.5), math.floor(3.8)))
print(string.upper("Lua") .. ":" .. string.lower("SHELL") .. ":" .. string.rep("ab", 3))
print(string.reverse("abc") .. ":" .. string.sub("abcdef", -4, -2))
print(string.char(65, 66) .. ":" .. string.byte("A") .. ":" .. string.find("hello world", "world", 1, true))
print(string.format("%.2f", math.pi))]],
            "ps1"
        )

        expect(result.code:find("function __luash_math_abs", 1, true) ~= nil).toBeTruthy()
        expect(result.code:find("function __luash_string_format", 1, true) ~= nil).toBeTruthy()
        if result.executed then
            expect(result.ok).toBeTruthy()
            expect(result.output).toBe("4.5:3\nLUA:shell:ababab\ncba:cde\nAB:65:7\n3.14\n")
        end
    end)

    it("rejects unsupported multiple-return math calls", function()
        expect(function()
            helper.compileAndRunTarget("09_powershell_stdlib", [[print(math.frexp(8))]], "ps1")
        end).toThrow("returns multiple values")
    end)
end)

lust.report()
