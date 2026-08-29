package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("03 - Loop script", function()
    it("executes numeric, while, and repeat loops", function()
        local result = helper.compileAndRun(
            "03_loops",
            [[local total = 0
for i = 1, 3 do
    total = total + i
end
while total < 8 do
    total = total + 1
end
repeat
    total = total + 1
until total >= 10
print(total)]]
        )
        helper.expectOutput(result, "10\n")
    end)
end)

lust.report()
