package.path = package.path .. ";src/?.lua;src/?/init.lua;tests/?.lua;tests/?/init.lua"

local lust = require("Lust")
lust.injectGlobals()

local Lexer = require("lexer")

describe("Lexer", function()
    describe("Keywords", function()
        it("tokenizes all Lua keywords", function()
            local source = table.concat({
                "and break do else elseif end false for function goto if in local nil",
                "not or repeat return then true until while",
            }, " ")
            local tokens = Lexer.new(source):tokenize()
            local keywords = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "KEYWORD" then
                    table.insert(keywords, tok.value)
                end
            end
            expect(#keywords).toBe(22)
        end)

        it("distinguishes keywords from identifiers", function()
            local source = "local x = 1\nlocal function foo() end"
            local tokens = Lexer.new(source):tokenize()
            local kwCount = 0
            for _, tok in ipairs(tokens) do
                if tok.type == "KEYWORD" then
                    kwCount = kwCount + 1
                end
            end
            expect(kwCount).toBe(4) -- local, local, function, end
        end)
    end)

    describe("Identifiers", function()
        it("tokenizes simple identifiers", function()
            local tokens = Lexer.new("foo bar baz"):tokenize()
            local ids = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "IDENTIFIER" then
                    table.insert(ids, tok.value)
                end
            end
            expect(ids).toEqual({ "foo", "bar", "baz" })
        end)

        it("tokenizes identifiers with underscores and numbers", function()
            local tokens = Lexer.new("_var var2 _2var"):tokenize()
            local ids = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "IDENTIFIER" then
                    table.insert(ids, tok.value)
                end
            end
            expect(ids).toEqual({ "_var", "var2", "_2var" })
        end)
    end)

    describe("Numbers", function()
        it("tokenizes integers", function()
            local tokens = Lexer.new("42 0 123"):tokenize()
            local nums = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "NUMBER" then
                    table.insert(nums, tok.value)
                end
            end
            expect(nums).toEqual({ "42", "0", "123" })
        end)

        it("tokenizes floats", function()
            local tokens = Lexer.new("3.14 0.5 .5 1.0"):tokenize()
            local nums = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "NUMBER" then
                    table.insert(nums, tok.value)
                end
            end
            expect(nums).toEqual({ "3.14", "0.5", ".5", "1.0" })
        end)

        it("tokenizes hex numbers", function()
            local tokens = Lexer.new("0xFF 0x1A3F 0Xdeadbeef"):tokenize()
            local nums = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "NUMBER" then
                    table.insert(nums, tok.value)
                end
            end
            expect(nums).toEqual({ "0xFF", "0x1A3F", "0Xdeadbeef" })
        end)

        it("tokenizes scientific notation", function()
            local tokens = Lexer.new("1e10 3.14E-5 1e+5"):tokenize()
            local nums = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "NUMBER" then
                    table.insert(nums, tok.value)
                end
            end
            expect(nums).toEqual({ "1e10", "3.14E-5", "1e+5" })
        end)
    end)

    describe("Strings", function()
        it("tokenizes double-quoted strings", function()
            local tokens = Lexer.new('"hello" "world"'):tokenize()
            local strs = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "STRING" then
                    table.insert(strs, tok.value)
                end
            end
            expect(strs).toEqual({ "hello", "world" })
        end)

        it("tokenizes single-quoted strings", function()
            local tokens = Lexer.new("'hello' 'world'"):tokenize()
            local strs = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "STRING" then
                    table.insert(strs, tok.value)
                end
            end
            expect(strs).toEqual({ "hello", "world" })
        end)

        it("handles escaped characters", function()
            local tokens = Lexer.new("\"hello\\nworld\" 'it\\'s'"):tokenize()
            local strs = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "STRING" then
                    table.insert(strs, tok.value)
                end
            end
            -- Lexer returns raw string content with escapes preserved
            expect(strs[1]).toBe("hello\\nworld")
            expect(strs[2]).toBe("it\\'s")
        end)

        it("tokenizes long strings", function()
            local source = "[[hello world]]"
            local tokens = Lexer.new(source):tokenize()
            local strs = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "STRING" then
                    table.insert(strs, tok.value)
                end
            end
            expect(strs).toEqual({ "hello world" })
        end)

        it("tokenizes long strings with equals", function()
            local source = "[=[hello]=]"
            local tokens = Lexer.new(source):tokenize()
            local strs = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "STRING" then
                    table.insert(strs, tok.value)
                end
            end
            expect(strs).toEqual({ "hello" })
        end)
    end)

    describe("Operators", function()
        it("tokenizes multi-char operators", function()
            local source = "== ~= <= >= .. ... // << >> ::"
            local tokens = Lexer.new(source):tokenize()
            local ops = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "OPERATOR" then
                    table.insert(ops, tok.value)
                end
            end
            expect(ops).toEqual({ "==", "~=", "<=", ">=", "..", "...", "//", "<<", ">>", "::" })
        end)

        it("tokenizes single-char operators", function()
            local source = "+ - * / % ^ # & ~ | < > = ( ) { } [ ] ; : , ."
            local tokens = Lexer.new(source):tokenize()
            local ops = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "OPERATOR" then
                    table.insert(ops, tok.value)
                end
            end
            expect(#ops).toBe(23)
        end)
    end)

    describe("Comments", function()
        it("tokenizes short comments", function()
            local tokens = Lexer.new("-- this is a comment\nx = 1"):tokenize()
            local comments = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "COMMENT" then
                    table.insert(comments, tok.value)
                end
            end
            expect(comments).toEqual({ " this is a comment" })
        end)

        it("tokenizes long comments", function()
            local source = "--[[ long comment ]]\nx = 1"
            local tokens = Lexer.new(source):tokenize()
            local comments = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "COMMENT" then
                    table.insert(comments, tok.value)
                end
            end
            expect(comments).toEqual({ " long comment " })
        end)

        it("tokenizes nested long comments", function()
            local source = "--[=[ nested [[comment]] ]=]\nx = 1"
            local tokens = Lexer.new(source):tokenize()
            local comments = {}
            for _, tok in ipairs(tokens) do
                if tok.type == "COMMENT" then
                    table.insert(comments, tok.value)
                end
            end
            expect(comments).toEqual({ " nested [[comment]] " })
        end)
    end)

    describe("Whitespace and newlines", function()
        it("handles mixed whitespace", function()
            local tokens = Lexer.new("  \t x \n = \r 1 \n"):tokenize()
            local types = {}
            for _, tok in ipairs(tokens) do
                if tok.type ~= "EOF" then
                    table.insert(types, tok.type)
                end
            end
            expect(types).toEqual({ "IDENTIFIER", "OPERATOR", "NUMBER" })
        end)
    end)

    describe("Complex code", function()
        it("tokenizes a complete function", function()
            local source = [[
local function add(a, b)
	return a + b
end
]]
            local tokens = Lexer.new(source):tokenize()
            local types = {}
            for _, tok in ipairs(tokens) do
                if tok.type ~= "EOF" and tok.type ~= "COMMENT" then
                    table.insert(types, tok.type .. ":" .. tok.value)
                end
            end
            expect(#types > 10).toBeTruthy()
        end)
    end)
end)

lust.report()
