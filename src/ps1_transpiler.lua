-- ============================================================================
-- Target Transpiler: PowerShell (.ps1)
-- File: ps1_transpiler.lua
-- Implements: TranspilerInterface (./ITranspiler.lua file)
-- ============================================================================

local PS1Transpiler = {
	name = "ps1",
	extension = ".ps1",
}
PS1Transpiler.__index = PS1Transpiler

function PS1Transpiler.new()
	return setmetatable({}, PS1Transpiler)
end

function PS1Transpiler:transformExpr(luaExpr)
	if luaExpr.type == "Literal" then
		if type(luaExpr.value) == "boolean" then
			return { type = "PS1Boolean", value = luaExpr.value }
		elseif type(luaExpr.value) == "number" then
			return { type = "PS1Number", value = luaExpr.value }
		else
			return { type = "PS1String", value = tostring(luaExpr.value) }
		end
	elseif luaExpr.type == "Identifier" then
		return { type = "PS1VariableAccess", name = luaExpr.name }
	elseif luaExpr.type == "BinaryExpr" then
		local opMap = {
			["=="] = "-eq",
			["~="] = "-ne",
			["<"] = "-lt",
			[">"] = "-gt",
			["<="] = "-le",
			[">="] = "-ge",
			["+"] = "+",
			["-"] = "-",
			["*"] = "*",
			["/"] = "/",
			["%"] = "%",
		}
		return {
			type = "PS1BinaryExpr",
			operator = opMap[luaExpr.operator] or luaExpr.operator,
			left = self:transformExpr(luaExpr.left),
			right = self:transformExpr(luaExpr.right),
		}
	elseif luaExpr.type == "CallExpr" then
		local args = {}
		for _, arg in ipairs(luaExpr.args) do
			table.insert(args, self:transformExpr(arg))
		end
		return { type = "PS1FunctionCall", name = luaExpr.callee, args = args }
	end
	error("PS1Transpiler Error: Unsupported Lua AST expression: " .. tostring(luaExpr.type))
end

function PS1Transpiler:transformStmt(luaStmt)
	if luaStmt.type == "LocalVarDecl" or luaStmt.type == "AssignmentStmt" then
		return {
			type = "PS1Assignment",
			name = luaStmt.name,
			value = self:transformExpr(luaStmt.init),
		}
	elseif luaStmt.type == "IfStmt" then
		return {
			type = "PS1If",
			condition = self:transformExpr(luaStmt.condition),
			body = self:transformBlock(luaStmt.body),
		}
	elseif luaStmt.type == "FunctionDecl" then
		return {
			type = "PS1Function",
			name = luaStmt.name,
			params = luaStmt.params or {},
			body = self:transformBlock(luaStmt.body),
		}
	elseif luaStmt.type == "ReturnStmt" then
		return { type = "PS1Return", value = self:transformExpr(luaStmt.value) }
	elseif luaStmt.type == "ExprStmt" then
		return self:transformExpr(luaStmt.expr)
	end
	error("PS1Transpiler Error: Unsupported Lua AST statement: " .. tostring(luaStmt.type))
end

function PS1Transpiler:transformBlock(luaBlock)
	local block = {}
	for _, stmt in ipairs(luaBlock) do
		table.insert(block, self:transformStmt(stmt))
	end
	return block
end

function PS1Transpiler:translate(luaAST)
	return {
		type = "PS1Script",
		body = self:transformBlock(luaAST.body),
	}
end

-- --- Serializer ---
local Serializer = {}

function Serializer.serializeExpr(node)
	if node.type == "PS1String" then
		return string.format('"%s"', node.value)
	elseif node.type == "PS1Number" then
		return tostring(node.value)
	elseif node.type == "PS1Boolean" then
		return node.value and "$true" or "$false"
	elseif node.type == "PS1VariableAccess" then
		return string.format("$%s", node.name)
	elseif node.type == "PS1BinaryExpr" then
		return string.format(
			"(%s %s %s)",
			Serializer.serializeExpr(node.left),
			node.operator,
			Serializer.serializeExpr(node.right)
		)
	elseif node.type == "PS1FunctionCall" then
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
	if node.type == "PS1Assignment" then
		return string.format("%s$%s = %s", indent, node.name, Serializer.serializeExpr(node.value))
	elseif node.type == "PS1If" then
		local out = string.format("%sif %s {\n", indent, Serializer.serializeExpr(node.condition))
		for _, b in ipairs(node.body) do
			out = out .. Serializer.serializeStmt(b, pad) .. "\n"
		end
		return out .. indent .. "}"
	elseif node.type == "PS1Function" then
		local out = string.format("%sfunction %s {\n", indent, node.name)
		if #node.params > 0 then
			local paramVars = {}
			for _, p in ipairs(node.params) do
				table.insert(paramVars, "$" .. p)
			end
			out = out .. pad .. string.format("param(%s)\n", table.concat(paramVars, ", "))
		end
		for _, b in ipairs(node.body) do
			out = out .. Serializer.serializeStmt(b, pad) .. "\n"
		end
		return out .. indent .. "}"
	elseif node.type == "PS1Return" then
		return string.format("%sreturn %s", indent, Serializer.serializeExpr(node.value))
	elseif node.type == "PS1FunctionCall" then
		return indent .. Serializer.serializeExpr(node)
	end
	return ""
end

function Serializer.serialize(psAST)
	local lines = {}
	for _, stmt in ipairs(psAST.body) do
		table.insert(lines, Serializer.serializeStmt(stmt, ""))
	end
	return table.concat(lines, "\n")
end

PS1Transpiler.Serializer = Serializer
return PS1Transpiler
