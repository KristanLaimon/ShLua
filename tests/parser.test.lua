package.path = package.path .. ";src/?.lua;src/?/init.lua;tests/?.lua;tests/?/init.lua"

local lust = require("Lust")
lust.injectGlobals()

local Lexer = require("lexer")
local Parser = require("parser")

local function parse(source)
    local tokens = Lexer.new(source):tokenize()
    return Parser.new(tokens):parse()
end

describe("Parser", function()
    describe("Literals", function()
        it("parses numbers", function()
            local ast = parse("x = 42")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("AssignmentStmt")
            expect(stmt.init.type).toBe("Literal")
            expect(stmt.init.value).toBe(42)
        end)

        it("parses floats", function()
            local ast = parse("x = 3.14")
            local stmt = ast.body[1]
            expect(stmt.init.value).toBe(3.14)
        end)

        it("parses strings", function()
            local ast = parse('x = "hello"')
            local stmt = ast.body[1]
            expect(stmt.init.type).toBe("Literal")
            expect(stmt.init.value).toBe("hello")
        end)

        it("parses booleans", function()
            local ast = parse("x = true")
            expect(ast.body[1].init.value).toBe(true)
            ast = parse("x = false")
            expect(ast.body[1].init.value).toBe(false)
        end)

        it("parses nil", function()
            local ast = parse("x = nil")
            expect(ast.body[1].init.value).toBe(nil)
        end)
    end)

    describe("Variables", function()
        it("parses local variable declarations", function()
            local ast = parse("local x = 10")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("LocalVarDecl")
            expect(stmt.name).toBe("x")
            expect(stmt.init.value).toBe(10)
        end)

        it("parses global variable assignments", function()
            local ast = parse("x = 10")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("AssignmentStmt")
            expect(stmt.name).toBe("x")
        end)

        it("parses identifiers in expressions", function()
            local ast = parse("x = y")
            expect(ast.body[1].init.type).toBe("Identifier")
            expect(ast.body[1].init.name).toBe("y")
        end)
    end)

    describe("Binary Expressions", function()
        it("parses arithmetic operations", function()
            local ast = parse("x = 1 + 2")
            local expr = ast.body[1].init
            expect(expr.type).toBe("BinaryExpr")
            expect(expr.operator).toBe("+")
            expect(expr.left.value).toBe(1)
            expect(expr.right.value).toBe(2)
        end)

        it("parses comparison operations", function()
            local ast = parse("x = a < b")
            local expr = ast.body[1].init
            expect(expr.type).toBe("BinaryExpr")
            expect(expr.operator).toBe("<")
        end)

        it("parses equality operations", function()
            local ast = parse("x = a == b")
            expect(ast.body[1].init.operator).toBe("==")
            ast = parse("x = a ~= b")
            expect(ast.body[1].init.operator).toBe("~=")
        end)

        it("parses string concatenation", function()
            local ast = parse('x = "a" .. "b"')
            expect(ast.body[1].init.operator).toBe("..")
        end)

        it("respects operator precedence", function()
            local ast = parse("x = 1 + 2 * 3")
            local expr = ast.body[1].init
            expect(expr.operator).toBe("+")
            expect(expr.right.operator).toBe("*")
        end)

        it("parses chained operations", function()
            local ast = parse("x = 1 + 2 + 3")
            local expr = ast.body[1].init
            expect(expr.operator).toBe("+")
            expect(expr.left.operator).toBe("+")
        end)
    end)

    describe("Function Calls", function()
        it("parses simple function calls", function()
            local ast = parse("print(42)")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("ExprStmt")
            expect(stmt.expr.type).toBe("CallExpr")
            expect(stmt.expr.callee).toBe("print")
            expect(#stmt.expr.args).toBe(1)
            expect(stmt.expr.args[1].value).toBe(42)
        end)

        it("parses function calls with multiple arguments", function()
            local ast = parse("foo(1, 2, 3)")
            local args = ast.body[1].expr.args
            expect(#args).toBe(3)
            expect(args[1].value).toBe(1)
            expect(args[2].value).toBe(2)
            expect(args[3].value).toBe(3)
        end)

        it("parses nested function calls", function()
            local ast = parse("print(add(1, 2))")
            local call = ast.body[1].expr
            expect(call.callee).toBe("print")
            expect(call.args[1].callee).toBe("add")
        end)
    end)

    describe("Function Declarations", function()
        it("parses global function declarations", function()
            local ast = parse("function foo() end")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("FunctionDecl")
            expect(stmt.name).toBe("foo")
            expect(stmt.isLocal).toBe(false)
            expect(#stmt.params).toBe(0)
        end)

        it("parses function with parameters", function()
            local ast = parse("function foo(a, b, c) end")
            local params = ast.body[1].params
            expect(params).toEqual({ "a", "b", "c" })
        end)

        it("parses local function declarations", function()
            local ast = parse("local function foo() end")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("FunctionDecl")
            expect(stmt.name).toBe("foo")
            expect(stmt.isLocal).toBe(true)
        end)

        it("parses function body", function()
            local ast = parse("function foo() local x = 1 end")
            local body = ast.body[1].body
            expect(#body).toBe(1)
            expect(body[1].type).toBe("LocalVarDecl")
        end)
    end)

    describe("If Statements", function()
        it("parses simple if", function()
            local ast = parse("if x then y = 1 end")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("IfStmt")
            expect(stmt.condition.name).toBe("x")
            expect(#stmt.body).toBe(1)
        end)

        it("parses if with else", function()
            local ast = parse("if x then y = 1 else y = 2 end")
            local stmt = ast.body[1]
            expect(#stmt.body).toBe(1)
            -- else body is not separately represented in this AST
        end)

        it("parses elseif", function()
            local ast = parse("if x then y = 1 elseif z then y = 2 else y = 3 end")
            local stmt = ast.body[1]
            expect(stmt.type).toBe("IfStmt")
        end)
    end)

    describe("Return Statements", function()
        it("parses return with value", function()
            local ast = parse("function foo() return 42 end")
            local ret = ast.body[1].body[1]
            expect(ret.type).toBe("ReturnStmt")
            expect(ret.value.value).toBe(42)
        end)

        it("parses return in local function", function()
            local ast = parse("local function foo() return x end")
            local ret = ast.body[1].body[1]
            expect(ret.type).toBe("ReturnStmt")
            expect(ret.value.name).toBe("x")
        end)
    end)

    describe("Complex Programs", function()
        it("parses multiple statements", function()
            local ast = parse("local a = 1\nlocal b = 2\nc = a + b")
            expect(#ast.body).toBe(3)
        end)

        it("parses complete program with functions and logic", function()
            local source = [[
local function add(a, b)
	return a + b
end

local x = 10
local y = 20

if x < y then
	local result = add(x, y)
	return result
end
]]
            local ast = parse(source)
            expect(#ast.body).toBe(4) -- function, local x, local y, if
            expect(ast.body[1].type).toBe("FunctionDecl")
            expect(ast.body[2].type).toBe("LocalVarDecl")
            expect(ast.body[3].type).toBe("LocalVarDecl")
            expect(ast.body[4].type).toBe("IfStmt")
        end)
    end)

    describe("Unary Expressions", function()
        it("parses unary minus", function()
            local ast = parse("x = -5")
            local expr = ast.body[1].init
            expect(expr.type).toBe("UnaryExpr")
            expect(expr.operator).toBe("-")
            expect(expr.operand.value).toBe(5)
        end)

        it("parses not operator", function()
            local ast = parse("x = not true")
            local expr = ast.body[1].init
            expect(expr.type).toBe("UnaryExpr")
            expect(expr.operator).toBe("not")
        end)

        it("parses length operator", function()
            local ast = parse("x = #str")
            local expr = ast.body[1].init
            expect(expr.type).toBe("UnaryExpr")
            expect(expr.operator).toBe("#")
        end)
    end)

    describe("Parenthesized Expressions", function()
        it("parses parentheses for grouping", function()
            local ast = parse("x = (1 + 2) * 3")
            local expr = ast.body[1].init
            expect(expr.operator).toBe("*")
            expect(expr.left.operator).toBe("+")
        end)
    end)
end)

lust.report()
