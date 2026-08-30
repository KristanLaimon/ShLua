package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("08 - Bash math and string standard libraries", function()
    it("executes scalar math and string helpers", function()
        local result = helper.compileAndRunTarget(
            "08_bash_stdlib",
            [[print(math.abs(-4.5), math.ceil(-3.8), math.floor(-3.2), math.max(-2, 7, 4), math.min(-2, 7, 4))
print(math.sqrt(81), math.pow(2, 5), math.fmod(-7, 3))
print(string.upper("Lua"), string.lower("SHELL"), string.len("hello"), string.rep("ab", 3))
print(string.reverse("abc"), string.sub("abcdef", -4, -2), string.byte("A"), string.char(65, 66))
print(string.find("hello world", "world", 1, true))
print(string.format("%s %.2f", "value", 3.14159))
print(math.pi)]],
            "bash"
        )

        expect(result.code:find("__luash_math_abs", 1, true) ~= nil).toBeTruthy()
        expect(result.code:find("__luash_string_format", 1, true) ~= nil).toBeTruthy()
        if result.executed then
            expect(result.ok).toBeTruthy()
            expect(result.output).toBe(
                "4.5\t-3\t-4\t7\t-2\n"
                    .. "9\t32\t-1\n"
                    .. "LUA\tshell\t5\tababab\n"
                    .. "cba\tcde\t65\tAB\n"
                    .. "7\n"
                    .. "value 3.14\n"
                    .. "3.14159265358979323846\n"
            )
        end
    end)

    it("rejects library functions whose Lua semantics cannot be represented", function()
        expect(function()
            helper.compileAndRunTarget("08_bash_stdlib", [[print(string.gmatch("abc", "."))]], "bash")
        end).toThrow("requires Lua pattern matching")
        expect(function()
            helper.compileAndRunTarget("08_bash_stdlib", [[print(math.modf(1.5))]], "bash")
        end).toThrow("returns multiple values")
    end)
end)

lust.report()
