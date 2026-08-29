package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path
local lust = require("Lust")
lust.injectGlobals()
local Luash = require("luash")

describe("Bash basic regression", function()
    it("transpiles a callable function", function()
        local code = Luash.transpile("local function double(x) return x * 2 end print(double(4))", "bash")
        expect(code:find("double() {", 1, true) ~= nil).toBeTruthy()
        expect(code:find("printf '%s\\n' $(double 4)", 1, true) ~= nil).toBeTruthy()
    end)
end)

lust.report()
