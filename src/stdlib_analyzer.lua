local M = {}

local BASE_FUNCTIONS = {
    tonumber = true,
    tostring = true,
    type = true,
}

local LIBRARIES = {
    io = true,
    math = true,
    os = true,
    string = true,
    table = true,
}

---Maps a known global or dotted call name to its runtime library.
---@param name string Identifier or dotted callee name.
---@return string? library Library name, if supported.
local function libraryForName(name)
    if BASE_FUNCTIONS[name] then
        return "base"
    end
    if name == "pairs" or name == "ipairs" then
        return "table"
    end
    local prefix = name:match("^([%a_][%w_]*)%.")
    if prefix and LIBRARIES[prefix] then
        return prefix
    end
    return nil
end

---Gets or creates the mutable requirement record for a library.
---@param required table<string, table> Accumulated requirements.
---@param library string Library name.
---@return table record Requirement record.
local function requirement(required, library)
    if not required[library] then
        required[library] = { calls = {}, helpers = {} }
    end
    return required[library]
end

---Records a required standard-library call.
---@param required table<string, table> Accumulated requirements.
---@param library string Library name.
---@param name string Fully qualified call name.
---@return nil
local function requireCall(required, library, name)
    requirement(required, library).calls[name] = true
end

---Records a required runtime helper that has no direct source call.
---@param required table<string, table> Accumulated requirements.
---@param library string Library name.
---@param helper string Runtime helper name.
---@return nil
local function requireHelper(required, library, helper)
    requirement(required, library).helpers[helper] = true
end

---Finds the minimal standard-library runtime needed by a program AST.
---@param program ShLuaProgram Program to inspect.
---@return table<string, table> requirements Calls and helpers grouped by library.
function M.analyze(program)
    assert(program and program.type == "Program", "Stdlib analyzer expects a Program AST")
    local required = {}
    local visitExpression
    local visitStatements

    visitExpression = function(node)
        if not node then
            return
        elseif node.type == "Identifier" then
            local library = libraryForName(node.name)
            if library then
                requireCall(required, library, node.name)
            end
        elseif node.type == "CallExpr" then
            local library = libraryForName(node.callee)
            if library then
                requireCall(required, library, node.callee)
            end
            for _, argument in ipairs(node.args) do
                visitExpression(argument)
            end
        elseif node.type == "MethodCallExpr" then
            if node.method == "write" then
                requireHelper(required, "io", "__shlua_io_file_write")
            elseif node.method == "close" then
                requireHelper(required, "io", "__shlua_io_file_close")
            end
            visitExpression(node.receiver)
            for _, argument in ipairs(node.args) do
                visitExpression(argument)
            end
        elseif node.type == "UnaryExpr" then
            if node.operator == "#" then
                requireHelper(required, "table", "__shlua_length")
            end
            visitExpression(node.operand)
        elseif node.type == "BinaryExpr" then
            visitExpression(node.left)
            visitExpression(node.right)
        elseif node.type == "IndexExpr" then
            requireHelper(required, "table", "__shlua_table_get")
            visitExpression(node.table)
            visitExpression(node.key)
        elseif node.type == "TableConstructor" then
            requireHelper(required, "table", "__shlua_table_new")
            requireHelper(required, "table", "__shlua_table_set")
            for _, field in ipairs(node.fields) do
                visitExpression(field.key)
                visitExpression(field.value)
            end
        elseif node.type == "FunctionExpr" then
            visitStatements(node.body)
        end
    end

    visitStatements = function(statements)
        for _, statement in ipairs(statements) do
            if statement.type == "FunctionDecl" then
                visitStatements(statement.body)
            elseif statement.type == "IfStmt" then
                visitExpression(statement.condition)
                visitStatements(statement.body)
                for _, elseifNode in ipairs(statement.elseifs or {}) do
                    visitExpression(elseifNode.condition)
                    visitStatements(elseifNode.body)
                end
                if statement.elseBody then
                    visitStatements(statement.elseBody)
                end
            elseif statement.type == "NumericForStmt" then
                visitExpression(statement.startValue)
                visitExpression(statement.endValue)
                visitExpression(statement.stepValue)
                visitStatements(statement.body)
            elseif statement.type == "GenericForStmt" then
                visitExpression(statement.iterator)
                visitStatements(statement.body)
            elseif statement.type == "WhileStmt" or statement.type == "RepeatStmt" then
                visitExpression(statement.condition)
                visitStatements(statement.body)
            elseif statement.type == "DoStmt" then
                visitStatements(statement.body)
            elseif statement.type == "TableAssignmentStmt" then
                requireHelper(required, "table", "__shlua_table_set")
                visitExpression(statement.table)
                visitExpression(statement.key)
                visitExpression(statement.init)
            else
                visitExpression(statement.init or statement.value or statement.expr)
            end
        end
    end

    visitStatements(program.body)
    return required
end

return M
