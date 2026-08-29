package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local Lexer = require("lexer")
local Parser = require("parser")
local BashTranspiler = require("bash_transpiler")

local function transpile(source)
    local ast = Parser.new(Lexer.new(source):tokenize()):parse()
    return BashTranspiler.Serializer.serialize(BashTranspiler.new():translate(ast))
end

local function contains(text, expected)
    return text:find(expected, 1, true) ~= nil
end

describe("Bash Transpiler", function()
    it("emits safe assignments and arithmetic", function()
        local code = transpile([[local greeting = "it's $HOME"
local result = 1 + 2 * 3]])
        expect(contains(code, "greeting='it'\\''s $HOME'")).toBeTruthy()
        expect(contains(code, "result=$(( (1 + (2 * 3)) ))")).toBeTruthy()
    end)

    it("emits functions, command substitution, and returns", function()
        local code = transpile("local function add(a, b) return a + b end local result = add(2, 3)")
        expect(contains(code, "add() {")).toBeTruthy()
        expect(contains(code, 'local a="${1}"')).toBeTruthy()
        expect(contains(code, "result=$(add 2 3)")).toBeTruthy()
        expect(contains(code, "return 0")).toBeTruthy()
    end)

    it("emits nested conditionals and logical operators", function()
        local code = transpile([[if ready and count >= 2 then
    print("go", count)
elseif count == 1 then
    print("wait")
else
    print("stop")
end]])
        expect(contains(code, "&&")).toBeTruthy()
        expect(contains(code, "elif")).toBeTruthy()
        expect(contains(code, "printf '%s\\t%s\\n'")).toBeTruthy()
    end)

    it("emits an executable complex program", function()
        local code = transpile([[local function add(a, b)
    return a + b
end
local result = add(2, 3)
if result == 5 then
    print("sum=" .. result)
end]])
        expect(code:sub(1, 19)).toBe("#!/usr/bin/env bash")
        expect(contains(code, "'sum='\"${result}\"")).toBeTruthy()
    end)
end)

lust.report()
