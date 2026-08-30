-- Recursive-descent parser for the Lua subset supported by ShLua.

---@class Parser
---@field tokens ShLuaToken[] Token stream ending in EOF.
---@field pos integer One-based token cursor.
local Parser = {}
Parser.__index = Parser

---Creates a recursive-descent parser for a token stream.
---@param tokens ShLuaToken[] Tokens produced by `Lexer:tokenize`.
---@return Parser parser New parser instance.
function Parser.new(tokens)
    return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

---Returns a token at a relative cursor offset.
---@param offset? integer Offset from the current token.
---@return ShLuaToken? token Token at the requested position.
function Parser:peek(offset)
    offset = offset or 0
    return self.tokens[self.pos + offset]
end

---Consumes and returns the current non-EOF token.
---@return ShLuaToken? token Consumed token, or EOF when present.
function Parser:advance()
    local token = self:peek()
    if token and token.type ~= "EOF" then
        self.pos = self.pos + 1
    end
    return token
end

---Consumes a token only when it matches the expected type and optional value.
---@param tokenType ShLuaTokenType Expected token category.
---@param value? string Expected token text.
---@return ShLuaToken token Matching token.
function Parser:expect(tokenType, value)
    local token = self:peek()
    if not token or token.type ~= tokenType or (value and token.value ~= value) then
        error(
            string.format(
                "Parse Error: expected %s %s, got %s '%s' at line %d",
                tokenType,
                value or "",
                token and token.type or "EOF",
                token and token.value or "",
                token and token.line or -1
            )
        )
    end
    return self:advance()
end

---Returns the precedence assigned to an infix operator.
---@param operator string Lua operator.
---@return integer? precedence Operator precedence, if supported.
function Parser:getOperatorPrecedence(operator)
    local precedences = {
        ["or"] = 1,
        ["and"] = 2,
        ["=="] = 3,
        ["~="] = 3,
        ["<"] = 3,
        [">"] = 3,
        ["<="] = 3,
        [">="] = 3,
        [".."] = 4,
        ["+"] = 5,
        ["-"] = 5,
        ["*"] = 6,
        ["/"] = 6,
        ["%"] = 6,
        ["^"] = 8,
    }
    return precedences[operator]
end

---Parses an expression using precedence climbing.
---@param minPrecedence? integer Lowest operator precedence to consume.
---@return ShLuaExpression expression Parsed expression node.
function Parser:parseExpression(minPrecedence)
    minPrecedence = minPrecedence or 0
    local left = self:parsePrimary()

    while true do
        local token = self:peek()
        local isWordOperator = token and token.type == "KEYWORD" and (token.value == "and" or token.value == "or")
        local isSymbolOperator = token and token.type == "OPERATOR"
        if not isWordOperator and not isSymbolOperator then
            break
        end

        local precedence = self:getOperatorPrecedence(token.value)
        if not precedence or precedence < minPrecedence then
            break
        end

        local operator = self:advance().value
        local rightAssociative = operator == "^" or operator == ".."
        local right = self:parseExpression(precedence + (rightAssociative and 0 or 1))
        left = { type = "BinaryExpr", operator = operator, left = left, right = right }
    end

    return left
end

---Parses a call after its dotted callee name has been recognized.
---@param callee string Fully qualified callee name.
---@return ShLuaExpression call Call expression node.
function Parser:parseCall(callee)
    self:expect("OPERATOR", "(")
    local arguments = {}
    if self:peek().value ~= ")" then
        repeat
            table.insert(arguments, self:parseExpression())
            if self:peek().value ~= "," then
                break
            end
            self:advance()
        until false
    end
    self:expect("OPERATOR", ")")
    return { type = "CallExpr", callee = callee, args = arguments }
end

---Recognizes a one-string-argument `require` call used in a local declaration.
---@param expression ShLuaExpression Expression to inspect.
---@return string? moduleName Required module name.
local function requireModule(expression)
    if expression.type ~= "CallExpr" or expression.callee ~= "require" or #expression.args ~= 1 then
        return nil
    end
    local argument = expression.args[1]
    if argument.type ~= "Literal" or type(argument.value) ~= "string" then
        return nil
    end
    return argument.value
end

---Converts an identifier/index chain into a dotted name when possible.
---@param node ShLuaExpression Expression to inspect.
---@return string? name Dotted name for a static field chain.
local function dottedName(node)
    if node.type == "Identifier" then
        return node.name
    elseif node.type == "IndexExpr" and node.key.type == "Literal" and type(node.key.value) == "string" then
        local prefix = dottedName(node.table)
        if prefix then
            return prefix .. "." .. node.key.value
        end
    end
    return nil
end

local DOTTED_GLOBALS = {
    coroutine = true,
    io = true,
    math = true,
    os = true,
    string = true,
    table = true,
}

---Parses a Lua table constructor and its keyed or sequential fields.
---@return ShLuaExpression constructor Table constructor node.
function Parser:parseTableConstructor()
    self:expect("OPERATOR", "{")
    local fields = {}
    local sequenceIndex = 1

    while self:peek().value ~= "}" do
        local key
        local value
        local implicit = false
        if self:peek().value == "[" then
            self:advance()
            key = self:parseExpression()
            self:expect("OPERATOR", "]")
            self:expect("OPERATOR", "=")
            value = self:parseExpression()
        elseif self:peek().type == "IDENTIFIER" and self:peek(1) and self:peek(1).value == "=" then
            key = { type = "Literal", value = self:advance().value }
            self:advance()
            value = self:parseExpression()
        else
            key = { type = "Literal", value = sequenceIndex }
            value = self:parseExpression()
            implicit = true
            sequenceIndex = sequenceIndex + 1
        end
        table.insert(fields, { key = key, value = value, implicit = implicit })

        if self:peek().value ~= "," and self:peek().value ~= ";" then
            break
        end
        self:advance()
        if self:peek().value == "}" then
            break
        end
    end

    self:expect("OPERATOR", "}")
    return { type = "TableConstructor", fields = fields }
end

---Parses a comma-separated function parameter list.
---@return string[] parameters Parameter names in declaration order.
function Parser:parseParameterList()
    self:expect("OPERATOR", "(")
    local params = {}
    if self:peek().value ~= ")" then
        repeat
            table.insert(params, self:expect("IDENTIFIER").value)
            if self:peek().value ~= "," then
                break
            end
            self:advance()
        until false
    end
    self:expect("OPERATOR", ")")
    return params
end

---Parses an anonymous function expression.
---@return ShLuaExpression expression Function expression node.
function Parser:parseFunctionExpression()
    self:expect("KEYWORD", "function")
    local params = self:parseParameterList()
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "FunctionExpr", params = params, body = body }
end

---Parses a literal, identifier, unary expression, or postfix expression.
---@return ShLuaExpression expression Parsed primary expression.
function Parser:parsePrimary()
    local token = self:peek()
    if not token then
        error("Parse Error: unexpected end of input in expression")
    end

    if token.type == "OPERATOR" and (token.value == "-" or token.value == "#") then
        local operator = self:advance().value
        return { type = "UnaryExpr", operator = operator, operand = self:parseExpression(7) }
    elseif token.type == "KEYWORD" and token.value == "not" then
        self:advance()
        return { type = "UnaryExpr", operator = "not", operand = self:parseExpression(7) }
    end

    local expression
    if token.type == "NUMBER" then
        expression = { type = "Literal", value = tonumber(self:advance().value) }
    elseif token.type == "STRING" then
        expression = { type = "Literal", value = self:advance().value }
    elseif token.type == "KEYWORD" and (token.value == "true" or token.value == "false") then
        expression = { type = "Literal", value = self:advance().value == "true" }
    elseif token.type == "KEYWORD" and token.value == "nil" then
        self:advance()
        expression = { type = "Literal", value = nil }
    elseif token.type == "KEYWORD" and token.value == "function" then
        expression = self:parseFunctionExpression()
    elseif token.type == "OPERATOR" and token.value == "{" then
        expression = self:parseTableConstructor()
    elseif token.type == "IDENTIFIER" then
        expression = { type = "Identifier", name = self:advance().value }
    elseif token.type == "OPERATOR" and token.value == "(" then
        self:advance()
        expression = self:parseExpression()
        self:expect("OPERATOR", ")")
    else
        error(string.format("Parse Error: unexpected token in expression: %s '%s'", token.type, token.value))
    end

    while self:peek() do
        if self:peek().value == "." then
            self:advance()
            expression = {
                type = "IndexExpr",
                table = expression,
                key = { type = "Literal", value = self:expect("IDENTIFIER").value },
            }
        elseif self:peek().value == "[" then
            self:advance()
            expression = { type = "IndexExpr", table = expression, key = self:parseExpression() }
            self:expect("OPERATOR", "]")
        elseif self:peek().value == "(" then
            local callee = dottedName(expression)
            if not callee then
                error("Parse Error: calls through indexed expressions are not supported")
            end
            expression = self:parseCall(callee)
        elseif self:peek().value == ":" then
            self:advance()
            local method = self:expect("IDENTIFIER").value
            self:expect("OPERATOR", "(")
            local arguments = {}
            if self:peek().value ~= ")" then
                repeat
                    table.insert(arguments, self:parseExpression())
                    if self:peek().value ~= "," then
                        break
                    end
                    self:advance()
                until false
            end
            self:expect("OPERATOR", ")")
            expression = { type = "MethodCallExpr", receiver = expression, method = method, args = arguments }
        else
            break
        end
    end
    local name = dottedName(expression)
    local prefix = name and name:match("^([%a_][%w_]*)%.")
    if prefix and DOTTED_GLOBALS[prefix] then
        return { type = "Identifier", name = name }
    end
    return expression
end

---Parses the remaining identifiers in a comma-separated name list.
---@param firstName string First already-consumed name.
---@return string[] names Full name list.
function Parser:parseNameList(firstName)
    local names = { firstName }
    while self:peek() and self:peek().value == "," do
        self:advance()
        table.insert(names, self:expect("IDENTIFIER").value)
    end
    return names
end

---Parses an if/elseif/else statement and nested blocks.
---@return ShLuaStatement statement If statement node.
function Parser:parseIfStatement()
    self:expect("KEYWORD", "if")
    local condition = self:parseExpression()
    self:expect("KEYWORD", "then")
    local statement = {
        type = "IfStmt",
        condition = condition,
        body = self:parseBlock({ "else", "elseif", "end" }),
    }

    statement.elseifs = {}
    while self:peek().type == "KEYWORD" and self:peek().value == "elseif" do
        self:advance()
        local elseifCondition = self:parseExpression()
        self:expect("KEYWORD", "then")
        table.insert(statement.elseifs, {
            condition = elseifCondition,
            body = self:parseBlock({ "else", "elseif", "end" }),
        })
    end
    if #statement.elseifs == 0 then
        statement.elseifs = nil
    end

    if self:peek().type == "KEYWORD" and self:peek().value == "else" then
        self:advance()
        statement.elseBody = self:parseBlock({ "end" })
    end
    self:expect("KEYWORD", "end")
    return statement
end

---Parses a while loop.
---@return ShLuaStatement statement While statement node.
function Parser:parseWhileStatement()
    self:expect("KEYWORD", "while")
    local condition = self:parseExpression()
    self:expect("KEYWORD", "do")
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "WhileStmt", condition = condition, body = body }
end

---Parses a repeat/until loop.
---@return ShLuaStatement statement Repeat statement node.
function Parser:parseRepeatStatement()
    self:expect("KEYWORD", "repeat")
    local body = self:parseBlock({ "until" })
    self:expect("KEYWORD", "until")
    return { type = "RepeatStmt", body = body, condition = self:parseExpression() }
end

---Parses a scoped do/end block.
---@return ShLuaStatement statement Do statement node.
function Parser:parseDoStatement()
    self:expect("KEYWORD", "do")
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "DoStmt", body = body }
end

---Parses a named function declaration.
---@param isLocal boolean Whether the declaration follows `local`.
---@return ShLuaStatement statement Function declaration node.
function Parser:parseFunctionDecl(isLocal)
    self:expect("KEYWORD", "function")
    local name = self:expect("IDENTIFIER").value
    local params = self:parseParameterList()
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "FunctionDecl", name = name, params = params, body = body, isLocal = isLocal }
end

---Parses a numeric or generic for loop.
---@return ShLuaStatement statement For statement node.
function Parser:parseForStatement()
    self:expect("KEYWORD", "for")
    local firstName = self:expect("IDENTIFIER").value
    if self:peek().value == "=" then
        self:advance()
        local startValue = self:parseExpression()
        self:expect("OPERATOR", ",")
        local endValue = self:parseExpression()
        local stepValue = { type = "Literal", value = 1 }
        if self:peek().value == "," then
            self:advance()
            stepValue = self:parseExpression()
        end
        self:expect("KEYWORD", "do")
        local body = self:parseBlock({ "end" })
        self:expect("KEYWORD", "end")
        return {
            type = "NumericForStmt",
            name = firstName,
            startValue = startValue,
            endValue = endValue,
            stepValue = stepValue,
            body = body,
        }
    end

    local names = self:parseNameList(firstName)
    self:expect("KEYWORD", "in")
    local iterator = self:parseExpression()
    self:expect("KEYWORD", "do")
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "GenericForStmt", names = names, iterator = iterator, body = body }
end

---Parses one statement at the current token position.
---@return ShLuaStatement statement Parsed statement node.
function Parser:parseStatement()
    local token = self:peek()
    if token.type == "COMMENT" or (token.type == "OPERATOR" and token.value == ";") then
        self:advance()
        return { type = "NoOp" }
    end

    if token.type == "KEYWORD" and token.value == "local" then
        self:advance()
        if self:peek().type == "KEYWORD" and self:peek().value == "function" then
            return self:parseFunctionDecl(true)
        end
        local names = self:parseNameList(self:expect("IDENTIFIER").value)
        local init = { type = "Literal", value = nil }
        if self:peek().value == "=" then
            self:advance()
            init = self:parseExpression()
        end
        if #names == 1 then
            local module = requireModule(init)
            if module then
                return { type = "RequireStmt", name = names[1], module = module }
            end
            return { type = "LocalVarDecl", name = names[1], init = init }
        end
        return { type = "MultiLocalVarDecl", names = names, init = init }
    elseif token.type == "KEYWORD" and token.value == "function" then
        return self:parseFunctionDecl(false)
    elseif token.type == "KEYWORD" and token.value == "if" then
        return self:parseIfStatement()
    elseif token.type == "KEYWORD" and token.value == "while" then
        return self:parseWhileStatement()
    elseif token.type == "KEYWORD" and token.value == "repeat" then
        return self:parseRepeatStatement()
    elseif token.type == "KEYWORD" and token.value == "for" then
        return self:parseForStatement()
    elseif token.type == "KEYWORD" and token.value == "do" then
        return self:parseDoStatement()
    elseif token.type == "KEYWORD" and token.value == "break" then
        self:advance()
        return { type = "BreakStmt" }
    elseif token.type == "KEYWORD" and token.value == "return" then
        self:advance()
        local nextToken = self:peek()
        if
            not nextToken
            or nextToken.type == "EOF"
            or (nextToken.type == "OPERATOR" and nextToken.value == ";")
            or (
                nextToken.type == "KEYWORD"
                and (
                    nextToken.value == "end"
                    or nextToken.value == "else"
                    or nextToken.value == "elseif"
                    or nextToken.value == "until"
                )
            )
        then
            return { type = "ReturnStmt", value = { type = "Literal", value = nil } }
        end
        return { type = "ReturnStmt", value = self:parseExpression() }
    elseif token.type == "IDENTIFIER" then
        local expression = self:parseExpression()
        if self:peek() and self:peek().value == "=" then
            self:advance()
            local init = self:parseExpression()
            if expression.type == "Identifier" then
                return { type = "AssignmentStmt", name = expression.name, init = init }
            elseif expression.type == "IndexExpr" then
                return { type = "TableAssignmentStmt", table = expression.table, key = expression.key, init = init }
            end
            error("Parse Error: invalid assignment target")
        elseif self:peek() and self:peek().value == "," then
            if expression.type ~= "Identifier" then
                error("Parse Error: multiple assignment targets must be identifiers")
            end
            local names = self:parseNameList(expression.name)
            self:expect("OPERATOR", "=")
            local init = self:parseExpression()
            return { type = "MultiAssignmentStmt", names = names, init = init }
        end
        return { type = "ExprStmt", expr = expression }
    end

    error(string.format("Parse Error: unknown statement token %s '%s' at line %d", token.type, token.value, token.line))
end

---Parses statements until one of the provided keywords is encountered.
---@param terminators string[] Keywords that end this block.
---@return ShLuaStatement[] statements Statements in the block.
function Parser:parseBlock(terminators)
    local statements = {}
    local terminatorMap = {}
    for _, terminator in ipairs(terminators) do
        terminatorMap[terminator] = true
    end

    while self:peek() and self:peek().type ~= "EOF" do
        local token = self:peek()
        if token.type == "KEYWORD" and terminatorMap[token.value] then
            break
        end
        local statement = self:parseStatement()
        if statement.type ~= "NoOp" then
            table.insert(statements, statement)
        end
    end
    return statements
end

---Parses the complete token stream into a program AST.
---@return ShLuaProgram program Root program node.
function Parser:parse()
    return { type = "Program", body = self:parseBlock({}) }
end

return Parser
