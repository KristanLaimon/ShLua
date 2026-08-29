package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("05 - Closure script", function()
    it("returns and calls an anonymous function", function()
        local result = helper.compileAndRun(
            "05_closures",
            [[local function make(prefix)
    return function(suffix)
        return prefix .. suffix
    end
end
local greet = make("hello ")
print(greet("Lua"))]]
        )
        helper.expectOutput(result, "hello Lua\n")
    end)
end)

lust.report()
