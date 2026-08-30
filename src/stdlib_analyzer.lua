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

local function requirement(required, library)
    if not required[library] then
        required[library] = { calls = {}, helpers = {} }
    end
    return required[library]
end

local function requireCall(required, library, name)
    requirement(required, library).calls[name] = true
end

local function requireHelper(required, library, helper)
    requirement(required, library).helpers[helper] = true
end

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
        elseif node.type == "UnaryExpr" then
            if node.operator == "#" then
                requireHelper(required, "table", "__luash_length")
            end
            visitExpression(node.operand)
        elseif node.type == "BinaryExpr" then
            visitExpression(node.left)
            visitExpression(node.right)
        elseif node.type == "IndexExpr" then
            requireHelper(required, "table", "__luash_table_get")
            visitExpression(node.table)
            visitExpression(node.key)
        elseif node.type == "TableConstructor" then
            requireHelper(required, "table", "__luash_table_new")
            requireHelper(required, "table", "__luash_table_set")
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
                requireHelper(required, "table", "__luash_table_set")
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
