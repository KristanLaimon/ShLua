package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

describe("06 - Coroutine script", function()
    it("executes the alpha coroutine lifecycle", function()
        local result = helper.compileAndRun(
            "06_coroutines",
            [[local function worker()
    coroutine.yield("one")
    return "done"
end
local handle = coroutine.create(worker)
local ok, value = coroutine.resume(handle)
print(value)
ok, value = coroutine.resume(handle)
print(value)]]
        )
        helper.expectOutput(result, "one\ndone\n")
    end)
end)

lust.report()
