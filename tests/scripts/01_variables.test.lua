package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("01 - Variables and expressions", function()
    it("evaluates primitives, arithmetic, and concatenation", function()
        local result = helper.compileAndRun(
            "01_variables",
            [[local number = 2 + 3 * 4
local text = "value=" .. number
print(text)]]
        )
        helper.expectOutput(result, "value=14\n")
    end)
end)

lust.report()
