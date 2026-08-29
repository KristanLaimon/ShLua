-- ============================================================================
-- Lua AST Generator (Parser)
-- File: lua_ast_generator.lua
-- Accepts: Token Stream from Lexer -> Outputs: Lua AST
-- ============================================================================

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
	local self = setmetatable({}, Parser)
	self.tokens = tokens
	self.pos = 1
	return self
end

function Parser:peek(offset)
	offset = offset or 0
	return self.tokens[self.pos + offset]
end

function Parser:advance()
	local tok = self:peek()
	if tok and tok.type ~= "EOF" then
		self.pos = self.pos + 1
	end
	return tok
end

function Parser:expect(type, val)
	local tok = self:peek()
	if not tok or tok.type ~= type or (val and tok.value ~= val) then
		error(
			string.format(
				"Parse Error: Expected %s %s, got %s '%s' at line %d",
				type,
				val or "",
				tok and tok.type or "EOF",
				tok and tok.value or "",
				tok and tok.line or -1
			)
		)
	end
	return self:advance()
end

-- Expression Parsing
function Parser:parseExpression()
	local left = self:parsePrimary()
	local tok = self:peek()

	if tok and tok.type == "OPERATOR" and tok.value:match("[+%-%*/%%==~=<>]") then
		local op = self:advance().value
		local right = self:parseExpression()
		return {
			type = "BinaryExpr",
			operator = op,
			left = left,
			right = right,
		}
	end
	return left
end

function Parser:parsePrimary()
	local tok = self:peek()

	if tok.type == "NUMBER" then
		return { type = "Literal", value = tonumber(self:advance().value) }
	elseif tok.type == "STRING" then
		return { type = "Literal", value = self:advance().value }
	elseif tok.type == "KEYWORD" and (tok.value == "true" or tok.value == "false") then
		return { type = "Literal", value = self:advance().value == "true" }
	elseif tok.type == "IDENTIFIER" then
		local id = self:advance().value
		-- Function Call check
		if self:peek() and self:peek().value == "(" then
			self:advance() -- skip '('
			local args = {}
			if self:peek().value ~= ")" then
				repeat
					table.insert(args, self:parseExpression())
					if self:peek().value == "," then
						self:advance()
					else
						break
					end
				until false
			end
			self:expect("OPERATOR", ")")
			return { type = "CallExpr", callee = id, args = args }
		end
		return { type = "Identifier", name = id }
	end

	error(string.format("Unexpected token in expression: %s '%s'", tok.type, tok.value))
end

-- Statement Parsing
function Parser:parseStatement()
	local tok = self:peek()

	-- Comments (No-op in AST)
	if tok.type == "COMMENT" then
		self:advance()
		return { type = "NoOp" }
	end

	-- Local Variable or Local Function Declaration
	if tok.type == "KEYWORD" and tok.value == "local" then
		self:advance()
		if self:peek(1) and self:peek(1).value == "=" then
			local varName = self:expect("IDENTIFIER").value
			self:expect("OPERATOR", "=")
			local expr = self:parseExpression()
			return { type = "LocalVarDecl", name = varName, init = expr }
		elseif self:peek().value == "function" then
			return self:parseFunctionDecl(true)
		end
	end

	-- Global Function Declaration
	if tok.type == "KEYWORD" and tok.value == "function" then
		return self:parseFunctionDecl(false)
	end

	-- If Statement
	if tok.type == "KEYWORD" and tok.value == "if" then
		self:advance()
		local condition = self:parseExpression()
		self:expect("KEYWORD", "then")
		local body = self:parseBlock({ "else", "elseif", "end" })
		self:expect("KEYWORD", "end")
		return { type = "IfStmt", condition = condition, body = body }
	end

	-- Return Statement
	if tok.type == "KEYWORD" and tok.value == "return" then
		self:advance()
		local expr = self:parseExpression()
		return { type = "ReturnStmt", value = expr }
	end

	-- Assignment or Standalone Expression
	if tok.type == "IDENTIFIER" then
		if self:peek(1) and self:peek(1).value == "=" then
			local varName = self:advance().value
			self:expect("OPERATOR", "=")
			local expr = self:parseExpression()
			return { type = "AssignmentStmt", name = varName, init = expr }
		else
			local expr = self:parseExpression()
			return { type = "ExprStmt", expr = expr }
		end
	end

	error(string.format("Unknown statement token: %s '%s' at line %d", tok.type, tok.value, tok.line))
end

function Parser:parseFunctionDecl(isLocal)
	if isLocal then
		self:expect("KEYWORD", "function")
	else
		self:advance()
	end
	local name = self:expect("IDENTIFIER").value
	self:expect("OPERATOR", "(")
	local params = {}
	if self:peek().value ~= ")" then
		repeat
			table.insert(params, self:expect("IDENTIFIER").value)
			if self:peek().value == "," then
				self:advance()
			else
				break
			end
		until false
	end
	self:expect("OPERATOR", ")")
	local body = self:parseBlock({ "end" })
	self:expect("KEYWORD", "end")

	return {
		type = "FunctionDecl",
		name = name,
		params = params,
		body = body,
		isLocal = isLocal,
	}
end

function Parser:parseBlock(terminators)
	local stmts = {}
	local termMap = {}
	for _, t in ipairs(terminators) do
		termMap[t] = true
	end

	while self:peek() and self:peek().type ~= "EOF" do
		local tok = self:peek()
		if tok.type == "KEYWORD" and termMap[tok.value] then
			break
		end
		local stmt = self:parseStatement()
		if stmt.type ~= "NoOp" then
			table.insert(stmts, stmt)
		end
	end
	return stmts
end

function Parser:parse()
	local ast = { type = "Program", body = {} }
	while self:peek() and self:peek().type ~= "EOF" do
		local stmt = self:parseStatement()
		if stmt.type ~= "NoOp" then
			table.insert(ast.body, stmt)
		end
	end
	return ast
end

return Parser
