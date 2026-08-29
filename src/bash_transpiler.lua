-- ============================================================================
-- AST Translator (Lua AST -> Bash AST & Code Serializer)
-- File: ast_translator.lua
-- Accepts: Lua AST -> Outputs: Bash AST & Target Shell Script
-- ============================================================================

local Translator = {}
Translator.__index = Translator

function Translator.new()
	return setmetatable({}, Translator)
end

-- ----------------------------------------------------------------------------
-- AST Transformation: Lua AST -> Bash AST Nodes
-- ----------------------------------------------------------------------------

function Translator:transformExpr(luaExpr)
	if luaExpr.type == "Literal" then
		return { type = "BashString", value = tostring(luaExpr.value) }
	elseif luaExpr.type == "Identifier" then
		return { type = "BashVariableAccess", name = luaExpr.name }
	elseif luaExpr.type == "BinaryExpr" then
		local opMap = { ["=="] = "-eq", ["~="] = "-ne", ["<"] = "-lt", [">"] = "-gt", ["<="] = "-le", [">="] = "-ge" }
		local isArith = luaExpr.operator:match("[+%-%*/%%]")

		if isArith then
			return {
				type = "BashArithmeticExpr",
				operator = luaExpr.operator,
				left = self:transformExpr(luaExpr.left),
				right = self:transformExpr(luaExpr.right),
			}
		else
			return {
				type = "BashTestExpr",
				operator = opMap[luaExpr.operator] or luaExpr.operator,
				left = self:transformExpr(luaExpr.left),
				right = self:transformExpr(luaExpr.right),
			}
		end
	elseif luaExpr.type == "CallExpr" then
		local args = {}
		for _, arg in ipairs(luaExpr.args) do
			table.insert(args, self:transformExpr(arg))
		end
		return { type = "BashCommandCall", name = luaExpr.callee, args = args }
	end

	error("Unsupported Lua AST expression node: " .. luaExpr.type)
end

function Translator:transformStmt(luaStmt)
	if luaStmt.type == "LocalVarDecl" or luaStmt.type == "AssignmentStmt" then
		return {
			type = "BashAssignment",
			name = luaStmt.name,
			isLocal = (luaStmt.type == "LocalVarDecl"),
			value = self:transformExpr(luaStmt.init),
		}
	elseif luaStmt.type == "IfStmt" then
		return {
			type = "BashIf",
			condition = self:transformExpr(luaStmt.condition),
			body = self:transformBlock(luaStmt.body),
		}
	elseif luaStmt.type == "FunctionDecl" then
		local body = {}
		-- Map parameters inside bash functions to positional variables $1, $2, ...
		for idx, param in ipairs(luaStmt.params) do
			table.insert(body, {
				type = "BashAssignment",
				name = param,
				isLocal = true,
				value = { type = "BashVariableAccess", name = tostring(idx) },
			})
		end
		for _, bStmt in ipairs(self:transformBlock(luaStmt.body)) do
			table.insert(body, bStmt)
		end

		return {
			type = "BashFunction",
			name = luaStmt.name,
			body = body,
		}
	elseif luaStmt.type == "ReturnStmt" then
		return {
			type = "BashReturn",
			value = self:transformExpr(luaStmt.value),
		}
	elseif luaStmt.type == "ExprStmt" then
		return self:transformExpr(luaStmt.expr)
	end

	error("Unsupported Lua AST statement node: " .. luaStmt.type)
end

function Translator:transformBlock(luaBlock)
	local bashBlock = {}
	for _, stmt in ipairs(luaBlock) do
		table.insert(bashBlock, self:transformStmt(stmt))
	end
	return bashBlock
end

function Translator:translate(luaAST)
	return {
		type = "BashScript",
		shebang = "#!/usr/bin/env bash",
		body = self:transformBlock(luaAST.body),
	}
end

-- ----------------------------------------------------------------------------
-- Bash AST Serializer (Bash AST -> Shell Script Output)
-- ----------------------------------------------------------------------------

local Serializer = {}

function Serializer.serializeExpr(node)
	if node.type == "BashString" then
		return string.format('"%s"', node.value)
	elseif node.type == "BashVariableAccess" then
		return string.format('"$%s"', node.name)
	elseif node.type == "BashArithmeticExpr" then
		return string.format(
			"$(( %s %s %s ))",
			Serializer.serializeExpr(node.left):gsub('"', ""),
			node.operator,
			Serializer.serializeExpr(node.right):gsub('"', "")
		)
	elseif node.type == "BashTestExpr" then
		return string.format(
			"[ %s %s %s ]",
			Serializer.serializeExpr(node.left),
			node.operator,
			Serializer.serializeExpr(node.right)
		)
	elseif node.type == "BashCommandCall" then
		local args = {}
		for _, a in ipairs(node.args) do
			table.insert(args, Serializer.serializeExpr(a))
		end
		return string.format("%s %s", node.name, table.concat(args, " "))
	end
	return ""
end

function Serializer.serializeStmt(node, indent)
	indent = indent or ""
	local pad = indent .. "    "

	if node.type == "BashAssignment" then
		local modifier = node.isLocal and "local " or ""
		return string.format("%s%s%s=%s", indent, modifier, node.name, Serializer.serializeExpr(node.value))
	elseif node.type == "BashIf" then
		local out = string.format("%sif %s; then\n", indent, Serializer.serializeExpr(node.condition))
		for _, b in ipairs(node.body) do
			out = out .. Serializer.serializeStmt(b, pad) .. "\n"
		end
		return out .. indent .. "fi"
	elseif node.type == "BashFunction" then
		local out = string.format("%s%s() {\n", indent, node.name)
		for _, b in ipairs(node.body) do
			out = out .. Serializer.serializeStmt(b, pad) .. "\n"
		end
		return out .. indent .. "}"
	elseif node.type == "BashReturn" then
		if node.value.type == "BashArithmeticExpr" or node.value.type == "BashString" then
			return string.format("%secho %s\n%sreturn 0", indent, Serializer.serializeExpr(node.value), indent)
		end
		return string.format("%sreturn %s", indent, Serializer.serializeExpr(node.value))
	elseif node.type == "BashCommandCall" then
		return indent .. Serializer.serializeExpr(node)
	end
	return ""
end

function Serializer.serialize(bashAST)
	local lines = { bashAST.shebang, "" }
	for _, stmt in ipairs(bashAST.body) do
		table.insert(lines, Serializer.serializeStmt(stmt, ""))
	end
	return table.concat(lines, "\n")
end

Translator.Serializer = Serializer
return Translator
