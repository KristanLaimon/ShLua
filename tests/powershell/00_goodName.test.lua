package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path
local lust = require("Lust")
lust.injectGlobals()
local Luash = require("luash")

describe("PowerShell basic regression", function()
    it("transpiles a callable function", function()
        local code = Luash.transpile("local function double(x) return x * 2 end print(double(4))", "ps1")
        expect(code:find("function double {", 1, true) ~= nil):toBeTruthy()
        expect(code:find("Write-Output $(double 4)", 1, true) ~= nil):toBeTruthy()
    end)
end)

lust.report()
