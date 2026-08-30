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
end)

lust.report()
