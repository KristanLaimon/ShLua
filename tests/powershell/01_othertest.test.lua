package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path
local lust = require("Lust")
lust.injectGlobals()
local Luash = require("luash")

describe("PowerShell complex regression", function()
    it("transpiles elseif and concatenation", function()
        local code = Luash.transpile(
            [[if count > 2 then
    print("many")
elseif count == 2 then
    print("count=" .. count)
else
    print("few")
end]],
            "ps1"
        )
        expect(code:find("} elseif (", 1, true) ~= nil).toBeTruthy()
        expect(code:find("('count=' + $count)", 1, true) ~= nil).toBeTruthy()
    end)
end)

lust.report()
