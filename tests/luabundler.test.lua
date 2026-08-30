package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local LuaBundler = require("luabundler")
local ShLua = require("shlua")

local ROOT = "tests/fixtures/bundler"

describe("LuaBundler", function()
    it("strips standard-library requires and orders nested local modules before their dependents", function()
        local bundle = LuaBundler.bundleFile(ROOT .. "/main.lua")

        expect(#bundle.modules).toBe(2)
        expect(bundle.modules[1].name).toBe("nested.decoration")
        expect(bundle.modules[2].name).toBe("nested.greeting")
        expect(bundle.source:find("require", 1, true) == nil).toBeTruthy()
        expect(bundle.source:find("function decorate", 1, true) < bundle.source:find("function greet", 1, true)).toBeTruthy()
    end)

    it("transpiles a module graph from a file without runtime require calls", function()
        local code = ShLua.transpileFile(ROOT .. "/main.lua", "bash")

        expect(code:find("require", 1, true) == nil).toBeTruthy()
        expect(code:find("decorate()", 1, true) ~= nil).toBeTruthy()
        expect(code:find("greet()", 1, true) ~= nil).toBeTruthy()
    end)

    it("rejects local modules when source-only compilation has no resolution root", function()
        expect(function()
            ShLua.transpile('local helper = require("helper")', "bash")
        end).toThrow("requires a rootPath")
    end)

    it("rejects cyclic local module dependencies", function()
        expect(function()
            ShLua.transpileFile(ROOT .. "/cycle_a.lua", "bash")
        end).toThrow("cyclic local module dependency")
    end)
end)

lust.report()
