-- Lexical binding resolver for the Lua subset supported by ShLua.

local ScopeResolver = {}
ScopeResolver.__index = ScopeResolver

local function copyCaptures(captures)
    local result = {}
    for _, capture in ipairs(captures) do
        table.insert(result, {
            name = capture.name,
            resolvedName = capture.resolvedName,
            kind = capture.kind,
        })
    end
    return result
end

function ScopeResolver.new()
    return setmetatable({
        scopes = { {} },
        bindingId = 0,
        functionDepth = 0,
        functionContexts = {},
    }, ScopeResolver)
end

function ScopeResolver:currentScope()
    return self.scopes[#self.scopes]
end

function ScopeResolver:enterScope()
    table.insert(self.scopes, {})
end

function ScopeResolver:leaveScope()
    table.remove(self.scopes)
end

function ScopeResolver:declare(name, kind, isLocal)
    local binding
    if isLocal then
        local context = self.functionContexts[#self.functionContexts]
        local isFunctionRoot = context and #self.scopes == context.scopeDepth
        local preserveName = #self.scopes == 1 or isFunctionRoot
        self.bindingId = self.bindingId + 1
        binding = {
            name = name,
            resolvedName = preserveName and name or "__shlua_local_" .. self.bindingId .. "_" .. name,
            kind = kind or "variable",
            isLocal = true,
            functionDepth = self.functionDepth,
        }
        self:currentScope()[name] = binding
    else
        local globalScope = self.scopes[1]
        binding = globalScope[name]
        if not binding then
            binding = {
                name = name,
                resolvedName = name,
                kind = kind or "variable",
                isLocal = false,
                functionDepth = 0,
            }
            globalScope[name] = binding
        elseif kind == "function" then
            binding.kind = kind
        end
    end
    return binding
end

function ScopeResolver:lookup(name)
    for index = #self.scopes, 1, -1 do
        local binding = self.scopes[index][name]
        if binding then
            return binding
        end
    end
    return self:declare(name, "variable", false)
end

function ScopeResolver:recordCapture(binding)
    if not binding.isLocal or binding.functionDepth >= self.functionDepth then
        return
    end
    local context = self.functionContexts[#self.functionContexts]
    if context and not context.captureMap[binding.resolvedName] then
        context.captureMap[binding.resolvedName] = true
        table.insert(context.captures, binding)
    end
end

function ScopeResolver:resolveName(name)
    local binding = self:lookup(name)
    self:recordCapture(binding)
    return binding
end

function ScopeResolver:resolveExpression(node)
    if not node then
        return
    elseif node.type == "Literal" then
        node.staticType = node.value == nil and "nil" or type(node.value)
    elseif node.type == "Identifier" then
        local binding = self:resolveName(node.name)
        node.resolvedName = binding.resolvedName
        node.bindingKind = binding.kind
        node.isLocal = binding.isLocal
        node.staticType = binding.valueType
    elseif node.type == "UnaryExpr" then
        self:resolveExpression(node.operand)
        if node.operator == "-" or node.operator == "#" then
            node.staticType = "number"
        elseif node.operator == "not" then
            node.staticType = "boolean"
        end
    elseif node.type == "BinaryExpr" then
        self:resolveExpression(node.left)
        self:resolveExpression(node.right)
        if
            node.operator == "+"
            or node.operator == "-"
            or node.operator == "*"
            or node.operator == "/"
            or node.operator == "%"
            or node.operator == "^"
        then
            node.staticType = "number"
        elseif node.operator == ".." then
            node.staticType = "string"
        elseif
            node.operator == "=="
            or node.operator == "~="
            or node.operator == "<"
            or node.operator == ">"
            or node.operator == "<="
            or node.operator == ">="
        then
            node.staticType = "boolean"
        end
    elseif node.type == "IndexExpr" then
        self:resolveExpression(node.table)
        self:resolveExpression(node.key)
    elseif node.type == "TableConstructor" then
        for _, field in ipairs(node.fields) do
            self:resolveExpression(field.key)
            self:resolveExpression(field.value)
        end
        node.staticType = "table"
    elseif node.type == "CallExpr" then
        if not node.callee:find("%.") then
            local binding = self:resolveName(node.callee)
            node.resolvedCallee = binding.resolvedName
            node.calleeKind = binding.kind
            node.calleeIsLocal = binding.isLocal
        end
        for _, argument in ipairs(node.args) do
            self:resolveExpression(argument)
        end
        if node.callee == "tostring" or node.callee == "type" or node.callee == "table.concat" then
            node.staticType = "string"
        elseif node.callee == "tonumber" or node.callee == "table.maxn" then
            node.staticType = "number"
        end
    elseif node.type == "MethodCallExpr" then
        self:resolveExpression(node.receiver)
        for _, argument in ipairs(node.args) do
            self:resolveExpression(argument)
        end
    elseif node.type == "FunctionExpr" then
        self:resolveFunction(node)
    end
end

function ScopeResolver:resolveFunction(node)
    self.functionDepth = self.functionDepth + 1
    local context = { captures = {}, captureMap = {} }
    table.insert(self.functionContexts, context)
    self:enterScope()
    context.scopeDepth = #self.scopes

    node.resolvedParams = {}
    for _, parameter in ipairs(node.params) do
        local binding = self:declare(parameter, "variable", true)
        table.insert(node.resolvedParams, binding.resolvedName)
    end
    self:resolveStatements(node.body, false)

    node.captures = copyCaptures(context.captures)
    self:leaveScope()
    table.remove(self.functionContexts)
    self.functionDepth = self.functionDepth - 1
end

function ScopeResolver:resolveScopedBody(statements)
    self:enterScope()
    self:resolveStatements(statements, false)
    self:leaveScope()
end

function ScopeResolver:resolveStatement(statement)
    if statement.type == "RequireStmt" then
        return
    elseif statement.type == "LocalVarDecl" then
        self:resolveExpression(statement.init)
        local binding = self:declare(statement.name, "variable", true)
        binding.valueType = statement.init.staticType
        statement.resolvedName = binding.resolvedName
    elseif statement.type == "MultiLocalVarDecl" then
        self:resolveExpression(statement.init)
        statement.resolvedNames = {}
        for _, name in ipairs(statement.names) do
            local binding = self:declare(name, "variable", true)
            table.insert(statement.resolvedNames, binding.resolvedName)
        end
    elseif statement.type == "AssignmentStmt" then
        self:resolveExpression(statement.init)
        local binding = self:resolveName(statement.name)
        binding.valueType = statement.init.staticType
        statement.resolvedName = binding.resolvedName
        statement.bindingIsLocal = binding.isLocal
        statement.functionDepth = self.functionDepth
        statement.isCapturedAssignment = binding.isLocal and binding.functionDepth < self.functionDepth
    elseif statement.type == "TableAssignmentStmt" then
        self:resolveExpression(statement.table)
        self:resolveExpression(statement.key)
        self:resolveExpression(statement.init)
    elseif statement.type == "MultiAssignmentStmt" then
        self:resolveExpression(statement.init)
        statement.resolvedNames = {}
        statement.capturedAssignments = {}
        for index, name in ipairs(statement.names) do
            local binding = self:resolveName(name)
            statement.resolvedNames[index] = binding.resolvedName
            statement.capturedAssignments[index] = binding.isLocal and binding.functionDepth < self.functionDepth
        end
    elseif statement.type == "FunctionDecl" then
        local binding
        if statement.isLocal then
            binding = self:declare(statement.name, "function", true)
        else
            binding = self:lookup(statement.name)
            binding.kind = "function"
        end
        statement.resolvedName = binding.resolvedName
        self:resolveFunction(statement)
        local captures = {}
        for _, capture in ipairs(statement.captures) do
            if capture.resolvedName == binding.resolvedName then
                statement.recursive = true
            else
                table.insert(captures, capture)
            end
        end
        statement.captures = captures
    elseif statement.type == "IfStmt" then
        self:resolveExpression(statement.condition)
        self:resolveScopedBody(statement.body)
        for _, elseifNode in ipairs(statement.elseifs or {}) do
            self:resolveExpression(elseifNode.condition)
            self:resolveScopedBody(elseifNode.body)
        end
        if statement.elseBody then
            self:resolveScopedBody(statement.elseBody)
        end
    elseif statement.type == "WhileStmt" then
        self:resolveExpression(statement.condition)
        self:resolveScopedBody(statement.body)
    elseif statement.type == "RepeatStmt" then
        self:enterScope()
        self:resolveStatements(statement.body, false)
        self:resolveExpression(statement.condition)
        self:leaveScope()
    elseif statement.type == "NumericForStmt" then
        self:resolveExpression(statement.startValue)
        self:resolveExpression(statement.endValue)
        self:resolveExpression(statement.stepValue)
        self:enterScope()
        local binding = self:declare(statement.name, "variable", true)
        statement.resolvedName = binding.resolvedName
        self:resolveStatements(statement.body, false)
        self:leaveScope()
    elseif statement.type == "GenericForStmt" then
        self:resolveExpression(statement.iterator)
        self:enterScope()
        statement.resolvedNames = {}
        for _, name in ipairs(statement.names) do
            local binding = self:declare(name, "variable", true)
            table.insert(statement.resolvedNames, binding.resolvedName)
        end
        self:resolveStatements(statement.body, false)
        self:leaveScope()
    elseif statement.type == "DoStmt" then
        self:resolveScopedBody(statement.body)
    elseif statement.type == "ReturnStmt" then
        self:resolveExpression(statement.value)
    elseif statement.type == "ExprStmt" then
        self:resolveExpression(statement.expr)
    end
end

function ScopeResolver:resolveStatements(statements)
    for _, statement in ipairs(statements) do
        self:resolveStatement(statement)
    end
end

function ScopeResolver.resolve(program)
    assert(program and program.type == "Program", "ScopeResolver expects a Program AST")
    if program.scopeResolved then
        return program
    end
    local resolver = ScopeResolver.new()
    resolver:resolveStatements(program.body)
    program.scopeResolved = true
    return program
end

return ScopeResolver
