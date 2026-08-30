package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local Lexer = require("lexer")
local Parser = require("parser")
local StdlibAnalyzer = require("stdlib_analyzer")
local Luash = require("luash")

local function analyze(source)
    local ast = Parser.new(Lexer.new(source):tokenize()):parse()
    return StdlibAnalyzer.analyze(ast)
end

describe("Standard-library analyzer", function()
    it("finds calls and constants throughout nested statements", function()
        local required = analyze([[local function render(value)
    if value then return string.format("%.2f", math.abs(value)) end
    return tostring(math.pi)
end
io.write(render(-1))]])
        expect(required.base).toBeTruthy()
        expect(required.io).toBeTruthy()
        expect(required.math).toBeTruthy()
        expect(required.string).toBeTruthy()
        expect(required.os).toBeFalsy()
    end)

    it("injects only referenced target-library modules", function()
        local bash = Luash.transpile([[print(string.rep("x", 2))]], "bash")
        expect(bash:find("__luash_string_rep", 1, true) ~= nil).toBeTruthy()
        expect(bash:find("__luash_math_abs", 1, true) ~= nil).toBeFalsy()
        expect(bash:find("__luash_os_clock", 1, true) ~= nil).toBeFalsy()

        local ps1 = Luash.transpile([[print(math.floor(2.5))]], "ps1")
        expect(ps1:find("function __luash_math_floor", 1, true) ~= nil).toBeTruthy()
        expect(ps1:find("function __luash_string_rep", 1, true) ~= nil).toBeFalsy()
    end)

    it("selects table support for syntax and generic iteration", function()
        local required = analyze([[local values = { name = "Luash" }
values[1] = values.name
for key, value in pairs(values) do print(key, value) end]])
        expect(required.table).toBeTruthy()

        local bash = Luash.transpile("local values = {}", "bash")
        expect(bash:find("__luash_table_new", 1, true) ~= nil).toBeTruthy()
        expect(bash:find("__luash_math_abs", 1, true) ~= nil).toBeFalsy()
    end)

    it("injects runtime helpers only when generated code needs them", function()
        for _, target in ipairs({ "bash", "ps1" }) do
            local minimal = Luash.transpile("print(1)", target)
            expect(minimal:find("__luash_coroutine_", 1, true) == nil).toBeTruthy()
            expect(minimal:find("__luash_call", 1, true) == nil).toBeTruthy()

            local closure = Luash.transpile(
                [[local value = "Luash"
local render = function() return value end
print(render())]],
                target
            )
            expect(closure:find("__luash_call", 1, true) ~= nil).toBeTruthy()
            expect(closure:find("__luash_coroutine_", 1, true) == nil).toBeTruthy()

            local coroutine = Luash.transpile(
                [[function worker()
    coroutine.yield("ready")
end
local handle = coroutine.create(worker)
local ok, value = coroutine.resume(handle)
print(ok, value)]],
                target
            )
            expect(coroutine:find("__luash_coroutine_", 1, true) ~= nil).toBeTruthy()
            expect(coroutine:find("__luash_call", 1, true) == nil).toBeTruthy()
        end

        local bash = Luash.transpile("print(1 + 2)", "bash")
        expect(bash:find("__luash_arithmetic", 1, true) ~= nil).toBeTruthy()
        local bashMinimal = Luash.transpile("print(1)", "bash")
        expect(bashMinimal:find("__luash_arithmetic", 1, true) == nil).toBeTruthy()

        local tableSort = Luash.transpile(
            [[local values = { 2, 1 }
local function descending(left, right) return left > right end
table.sort(values, descending)]],
            "ps1"
        )
        expect(tableSort:find("__luash_call", 1, true) ~= nil).toBeTruthy()
    end)
end)

lust.report()
