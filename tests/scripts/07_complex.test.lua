package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("07 - Complex script", function()
    it("combines closures, loops, locals, calls, and conditionals", function()
        local result = helper.compileAndRun(
            "07_complex",
            [[local function multiplier(factor)
    return function(value)
        return value * factor
    end
end
local double = multiplier(2)
local total = 0
for i = 1, 4 do
    local current = double(i)
    if current >= 6 then
        total = total + current
    end
end
print("total=" .. total)]]
        )
        helper.expectOutput(result, "total=14\n")
    end)
end)

lust.report()
