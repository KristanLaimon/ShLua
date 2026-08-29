package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("00 - Minimal script", function()
    it("prints one literal", function()
        local result = helper.compileAndRun("00_minimal", [[print("hello")]])
        helper.expectOutput(result, "hello\n")
    end)
end)

lust.report()
