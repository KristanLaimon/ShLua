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
        expect(contains(code, "result=\"$(__shlua_arithmetic 1 '+' \"$(__shlua_arithmetic 2 '*' 3)\")\"")).toBeTruthy()
    end)

    it("emits functions, command substitution, and returns", function()
        local code = transpile("local function add(a, b) return a + b end local result = add(2, 3)")
        expect(contains(code, "add() {")).toBeTruthy()
        expect(contains(code, 'local a="${1}"')).toBeTruthy()
        expect(contains(code, 'result="$(add 2 3)"')).toBeTruthy()
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

    it("emits loops and lexical block names", function()
        local code = transpile([[local value = "outer"
while ready do break end
repeat local value = "inner" until value == "inner"
for i = 3, 1, -1 do print(i) end
for index, item in ipairs(items) do print(index, item) end]])
        expect(contains(code, "while ")).toBeTruthy()
        expect(contains(code, "while :; do")).toBeTruthy()
        expect(contains(code, "__shlua_local_")).toBeTruthy()
        expect(contains(code, "__shlua_for_limit_")).toBeTruthy()
        expect(contains(code, "__shlua_for_collection_")).toBeTruthy()
    end)

    it("emits captured anonymous functions", function()
        local code = transpile([[local function make(prefix)
    return function(value) return prefix .. value end
end
local greet = make("hello ")
print(greet("Lua"))]])
        expect(contains(code, "__shlua_closure_1()")).toBeTruthy()
        expect(contains(code, '__shlua_call "${greet}"')).toBeTruthy()
    end)

    it("rejects writes to captured values instead of changing their meaning", function()
        expect(function()
            transpile([[local value = 1
local increment = function() value = value + 1 return value end
print(increment())]])
        end).toThrow("assignment to a captured closure variable")
    end)
end)

lust.report()
