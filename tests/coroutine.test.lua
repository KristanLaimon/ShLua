package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local Luash = require("luash")

local SOURCE = [[
local function worker()
    coroutine.yield("one")
    coroutine.yield("two")
    return "done"
end

local first = coroutine.create(worker)
local second = coroutine.create(worker)
local ok, value = coroutine.resume(first)
ok, value = coroutine.resume(first)
ok, value = coroutine.resume(second)
ok, value = coroutine.resume(first)
ok, value = coroutine.resume(first)
]]

describe("Alpha Coroutines", function()
    it("parses dotted calls and multiple assignment", function()
        local ast = Luash.parse(SOURCE)
        expect(ast.body[2].init.callee).toBe("coroutine.create")
        expect(ast.body[4].type).toBe("MultiLocalVarDecl")
        expect(ast.body[4].init.callee).toBe("coroutine.resume")
    end)

    it("emits independent stateful Bash handles", function()
        local code = Luash.transpile(SOURCE, "bash")
        expect(code:find("first__state=0", 1, true) ~= nil).toBeTruthy()
        expect(code:find("second__state=0", 1, true) ~= nil).toBeTruthy()
        expect(code:find("cannot resume dead coroutine", 1, true) ~= nil).toBeTruthy()
    end)

    it("emits independent stateful PowerShell handles", function()
        local code = Luash.transpile(SOURCE, "ps1")
        expect(code:find("$first = @{ Worker = 'worker'; State = 0", 1, true) ~= nil).toBeTruthy()
        expect(code:find("$second = @{ Worker = 'worker'; State = 0", 1, true) ~= nil).toBeTruthy()
        expect(code:find("cannot resume dead coroutine", 1, true) ~= nil).toBeTruthy()
    end)

    it("rejects unsupported worker control flow clearly", function()
        expect(function()
            Luash.transpile(
                [[local function worker()
    local value = 1
    coroutine.yield(value)
end
local co = coroutine.create(worker)]],
                "bash"
            )
        end).toThrow("support only sequential yield calls")
    end)

    it("rejects coroutine lifecycle calls below top level", function()
        expect(function()
            Luash.transpile(
                [[local function worker()
    coroutine.yield("value")
end
local function start()
    local co = coroutine.create(worker)
end]],
                "bash"
            )
        end).toThrow("must be used at top level")
    end)
end)

lust.report()
