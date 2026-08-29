package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local Lexer = require("lexer")
local Parser = require("parser")
local PS1Transpiler = require("ps1_transpiler")

local function transpile(source)
    local ast = Parser.new(Lexer.new(source):tokenize()):parse()
    return PS1Transpiler.Serializer.serialize(PS1Transpiler.new():translate(ast))
end

local function contains(text, expected)
    return text:find(expected, 1, true) ~= nil
end

describe("PowerShell Transpiler", function()
    it("emits values, arithmetic, and safe strings", function()
        local code = transpile([[local text = "it's $HOME"
local result = 1 + 2 * 3
local missing = nil]])
        expect(contains(code, "$text = 'it''s $HOME'")).toBeTruthy()
        expect(contains(code, "$result = (1 + (2 * 3))")).toBeTruthy()
        expect(contains(code, "$missing = $null")).toBeTruthy()
    end)

    it("emits functions, calls, and returns", function()
        local code = transpile("local function add(a, b) return a + b end local result = add(2, 3)")
        expect(contains(code, "function add {")).toBeTruthy()
        expect(contains(code, "param($a, $b)")).toBeTruthy()
        expect(contains(code, "$result = $(add 2 3)")).toBeTruthy()
    end)

    it("emits nested conditionals and logical operators", function()
        local code = transpile([[if ready and count >= 2 then
    print("go")
elseif count == 1 then
    print("wait")
else
    print("stop")
end]])
        expect(contains(code, "-and")).toBeTruthy()
        expect(contains(code, "} elseif (")).toBeTruthy()
        expect(contains(code, "Write-Output 'go'")).toBeTruthy()
    end)

    it("emits unary operations and exponentiation", function()
        local code = transpile("negative = -5 length = #name power = 2 ^ 3")
        expect(contains(code, "$negative = (-5)")).toBeTruthy()
        expect(contains(code, "$length = ($name).Length")).toBeTruthy()
        expect(contains(code, "$power = [Math]::Pow(2, 3)")).toBeTruthy()
    end)

    it("emits loops and anonymous closure objects", function()
        local code = transpile([[local function make(prefix)
    return function(value) return prefix .. value end
end
local greet = make("hello ")
for i = 1, 2 do print(greet(i)) end
for key, value in pairs(items) do print(key, value) end]])
        expect(contains(code, "function __luash_closure_1")).toBeTruthy()
        expect(contains(code, "Captures = @{")).toBeTruthy()
        expect(contains(code, "while (")).toBeTruthy()
        expect(contains(code, ".GetEnumerator()")).toBeTruthy()
    end)
end)

lust.report()
