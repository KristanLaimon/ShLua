package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("02 - Conditional script", function()
    it("selects an elseif branch", function()
        local result = helper.compileAndRun(
            "02_conditionals",
            [[local value = 2
if value > 2 then
    print("many")
elseif value == 2 then
    print("two")
else
    print("few")
end]]
        )
        helper.expectOutput(result, "two\n")
    end)
end)

lust.report()
