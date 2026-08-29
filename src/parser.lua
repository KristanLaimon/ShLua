-- Recursive-descent parser for the Lua subset supported by Luash.

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
    return setmetatable({ tokens = tokens, pos = 1 }, Parser)
end

function Parser:peek(offset)
    offset = offset or 0
    return self.tokens[self.pos + offset]
end

function Parser:advance()
    local token = self:peek()
    if token and token.type ~= "EOF" then
        self.pos = self.pos + 1
    end
    return token
end

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

function Parser:parseFunctionExpression()
    self:expect("KEYWORD", "function")
    local params = self:parseParameterList()
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "FunctionExpr", params = params, body = body }
end

function Parser:parsePrimary()
    local token = self:peek()
    if not token then
        error("Parse Error: unexpected end of input in expression")
    end

    if token.type == "NUMBER" then
        return { type = "Literal", value = tonumber(self:advance().value) }
    elseif token.type == "STRING" then
        return { type = "Literal", value = self:advance().value }
    elseif token.type == "KEYWORD" and (token.value == "true" or token.value == "false") then
        return { type = "Literal", value = self:advance().value == "true" }
    elseif token.type == "KEYWORD" and token.value == "nil" then
        self:advance()
        return { type = "Literal", value = nil }
    elseif token.type == "KEYWORD" and token.value == "function" then
        return self:parseFunctionExpression()
    elseif token.type == "IDENTIFIER" then
        local name = self:advance().value
        while self:peek() and self:peek().value == "." do
            self:advance()
            name = name .. "." .. self:expect("IDENTIFIER").value
        end
        if self:peek() and self:peek().value == "(" then
            return self:parseCall(name)
        end
        return { type = "Identifier", name = name }
    elseif token.type == "OPERATOR" and token.value == "(" then
        self:advance()
        local expression = self:parseExpression()
        self:expect("OPERATOR", ")")
        return expression
    elseif token.type == "OPERATOR" and (token.value == "-" or token.value == "#") then
        local operator = self:advance().value
        return { type = "UnaryExpr", operator = operator, operand = self:parseExpression(7) }
    elseif token.type == "KEYWORD" and token.value == "not" then
        self:advance()
        return { type = "UnaryExpr", operator = "not", operand = self:parseExpression(7) }
    end

    error(string.format("Parse Error: unexpected token in expression: %s '%s'", token.type, token.value))
end

function Parser:parseNameList(firstName)
    local names = { firstName }
    while self:peek() and self:peek().value == "," do
        self:advance()
        table.insert(names, self:expect("IDENTIFIER").value)
    end
    return names
end

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

function Parser:parseWhileStatement()
    self:expect("KEYWORD", "while")
    local condition = self:parseExpression()
    self:expect("KEYWORD", "do")
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "WhileStmt", condition = condition, body = body }
end

function Parser:parseRepeatStatement()
    self:expect("KEYWORD", "repeat")
    local body = self:parseBlock({ "until" })
    self:expect("KEYWORD", "until")
    return { type = "RepeatStmt", body = body, condition = self:parseExpression() }
end

function Parser:parseDoStatement()
    self:expect("KEYWORD", "do")
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "DoStmt", body = body }
end

function Parser:parseFunctionDecl(isLocal)
    self:expect("KEYWORD", "function")
    local name = self:expect("IDENTIFIER").value
    local params = self:parseParameterList()
    local body = self:parseBlock({ "end" })
    self:expect("KEYWORD", "end")
    return { type = "FunctionDecl", name = name, params = params, body = body, isLocal = isLocal }
end

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
        local nextToken = self:peek(1)
        if nextToken and (nextToken.value == "=" or nextToken.value == ",") then
            local names = self:parseNameList(self:advance().value)
            self:expect("OPERATOR", "=")
            local init = self:parseExpression()
            if #names == 1 then
                return { type = "AssignmentStmt", name = names[1], init = init }
            end
            return { type = "MultiAssignmentStmt", names = names, init = init }
        end
        return { type = "ExprStmt", expr = self:parseExpression() }
    end

    error(string.format("Parse Error: unknown statement token %s '%s' at line %d", token.type, token.value, token.line))
end

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

function Parser:parse()
    return { type = "Program", body = self:parseBlock({}) }
end

return Parser
