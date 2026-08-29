package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("04 - Function script", function()
    it("executes a recursive named function", function()
        local result = helper.compileAndRun(
            "04_functions",
            [[local function factorial(number)
    if number <= 1 then
        return 1
    end
    return number * factorial(number - 1)
end
print(factorial(5))]]
        )
        helper.expectOutput(result, "120\n")
    end)
end)

lust.report()
