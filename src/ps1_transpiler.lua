local PS1Transpiler = { name = "ps1", extension = ".ps1" }
PS1Transpiler.__index = PS1Transpiler

local function isCall(node, name)
    return node and node.type == "CallExpr" and node.callee == name
end

local function psQuote(value)
    return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function indent(level)
    return string.rep("    ", level)
end

local function validateCoroutinePlacement(statements, nested)
    for _, statement in ipairs(statements) do
        local call = statement.init or statement.expr
        if nested and (isCall(call, "coroutine.create") or isCall(call, "coroutine.resume")) then
            error("Coroutine Error: alpha create and resume calls must be used at top level")
        end
        if statement.type == "FunctionDecl" then
            validateCoroutinePlacement(statement.body, true)
        elseif statement.type == "IfStmt" then
            validateCoroutinePlacement(statement.body, true)
            for _, elseifNode in ipairs(statement.elseifs or {}) do
                validateCoroutinePlacement(elseifNode.body, true)
            end
            if statement.elseBody then
                validateCoroutinePlacement(statement.elseBody, true)
            end
        end
    end
end

function PS1Transpiler.new()
    return setmetatable({}, PS1Transpiler)
end

function PS1Transpiler:collectCoroutineWorkers(program)
    validateCoroutinePlacement(program.body, false)
    local workers = {}
    local functions = {}
    for _, statement in ipairs(program.body) do
        if statement.type == "FunctionDecl" then
            functions[statement.name] = statement
        elseif
            (statement.type == "LocalVarDecl" or statement.type == "AssignmentStmt")
            and isCall(statement.init, "coroutine.create")
        then
            local worker = statement.init.args[1]
            if #statement.init.args ~= 1 or not worker or worker.type ~= "Identifier" then
                error("Coroutine Error: coroutine.create expects one named function")
            end
            workers[worker.name] = true
        end
    end

    for workerName in pairs(workers) do
        local declaration = functions[workerName]
        if not declaration then
            error("Coroutine Error: worker function '" .. workerName .. "' is not declared")
        end
        if #declaration.params > 0 then
            error("Coroutine Error: alpha coroutine workers cannot have parameters")
        end
        local sawReturn = false
        for _, statement in ipairs(declaration.body) do
            local isYield = statement.type == "ExprStmt" and isCall(statement.expr, "coroutine.yield")
            if isYield then
                if sawReturn or #statement.expr.args > 1 then
                    error("Coroutine Error: yield accepts one value and cannot follow return")
                end
            elseif statement.type == "ReturnStmt" then
                if sawReturn then
                    error("Coroutine Error: coroutine worker can contain only one final return")
                end
                sawReturn = true
            else
                error("Coroutine Error: alpha workers support only sequential yield calls and a final return")
            end
        end
    end
    return workers
end

function PS1Transpiler:translate(luaAST)
    assert(luaAST and luaAST.type == "Program", "PS1Transpiler expects a Program AST")
    return {
        type = "PS1Script",
        program = luaAST,
        coroutineWorkers = self:collectCoroutineWorkers(luaAST),
    }
end

local Generator = {}
Generator.__index = Generator

function Generator.new(targetAST)
    return setmetatable({ workers = targetAST.coroutineWorkers }, Generator)
end

function Generator:command(node)
    if node.callee:find("%.") then
        error("PS1Transpiler Error: unsupported library call '" .. node.callee .. "'")
    end
    local arguments = {}
    for _, argument in ipairs(node.args) do
        table.insert(arguments, self:expression(argument))
    end
    local name = node.callee == "print" and "Write-Output" or node.callee
    return name .. (#arguments > 0 and " " .. table.concat(arguments, " ") or "")
end

function Generator:expression(node)
    if node.type == "Literal" then
        if node.value == nil then
            return "$null"
        elseif type(node.value) == "boolean" then
            return node.value and "$true" or "$false"
        elseif type(node.value) == "number" then
            return tostring(node.value)
        end
        return psQuote(node.value)
    elseif node.type == "Identifier" then
        if node.name:find("%.") then
            error("PS1Transpiler Error: dotted values are supported only as calls")
        end
        return "$" .. node.name
    elseif node.type == "CallExpr" then
        return "$(" .. self:command(node) .. ")"
    elseif node.type == "UnaryExpr" then
        if node.operator == "-" then
            return "(-" .. self:expression(node.operand) .. ")"
        elseif node.operator == "not" then
            return "(-not " .. self:expression(node.operand) .. ")"
        elseif node.operator == "#" then
            return "(" .. self:expression(node.operand) .. ").Length"
        end
    elseif node.type == "BinaryExpr" then
        if node.operator == "^" then
            return "[Math]::Pow(" .. self:expression(node.left) .. ", " .. self:expression(node.right) .. ")"
        end
        local operators = {
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
            [".."] = "+",
            ["and"] = "-and",
            ["or"] = "-or",
        }
        local operator = operators[node.operator]
        if operator then
            return "(" .. self:expression(node.left) .. " " .. operator .. " " .. self:expression(node.right) .. ")"
        end
    end
    error("PS1Transpiler Error: unsupported expression " .. tostring(node.type))
end

function Generator:coroutineWorker(statement, level)
    local output = {
        indent(level) .. "function __luash_coroutine_" .. statement.name .. " {",
        indent(level + 1) .. "param([hashtable] $__co)",
        indent(level + 1) .. "$__co.State = [int]$__co.State + 1",
        indent(level + 1) .. "switch ($__co.State) {",
    }
    local state = 0
    local returnValue = { type = "Literal", value = nil }
    for _, bodyStatement in ipairs(statement.body) do
        if bodyStatement.type == "ExprStmt" then
            state = state + 1
            local value = bodyStatement.expr.args[1] or { type = "Literal", value = nil }
            table.insert(output, indent(level + 2) .. state .. " { return @($true, " .. self:expression(value) .. ") }")
        else
            returnValue = bodyStatement.value
        end
    end
    state = state + 1
    table.insert(output, indent(level + 2) .. state .. " {")
    table.insert(output, indent(level + 3) .. "$__co.Dead = $true")
    table.insert(output, indent(level + 3) .. "return @($true, " .. self:expression(returnValue) .. ")")
    table.insert(output, indent(level + 2) .. "}")
    table.insert(output, indent(level + 2) .. "default { return @($false, 'cannot resume dead coroutine') }")
    table.insert(output, indent(level + 1) .. "}")
    table.insert(output, indent(level) .. "}")
    return table.concat(output, "\n")
end

function Generator:coroutineCreate(statement, level)
    local worker = statement.init.args[1].name
    return indent(level)
        .. "$"
        .. statement.name
        .. " = @{ Worker = "
        .. psQuote(worker)
        .. "; State = 0; Dead = $false }"
end

function Generator:coroutineResume(names, call, level)
    if #call.args ~= 1 or call.args[1].type ~= "Identifier" then
        error("Coroutine Error: coroutine.resume expects one coroutine variable")
    end
    if #names > 2 then
        error("Coroutine Error: alpha resume returns only success and one value")
    end
    local handle = self:expression(call.args[1])
    local output = {
        indent(level) .. "$__luash_resume = & ('__luash_coroutine_' + " .. handle .. ".Worker) " .. handle,
    }
    local values = { "$__luash_resume[0]", "$__luash_resume[1]" }
    for index, name in ipairs(names) do
        table.insert(output, indent(level) .. "$" .. name .. " = " .. values[index])
    end
    return table.concat(output, "\n")
end

function Generator:statement(statement, level)
    if statement.type == "FunctionDecl" then
        if self.workers[statement.name] then
            return self:coroutineWorker(statement, level)
        end
        local output = { indent(level) .. "function " .. statement.name .. " {" }
        if #statement.params > 0 then
            local params = {}
            for _, parameter in ipairs(statement.params) do
                table.insert(params, "$" .. parameter)
            end
            table.insert(output, indent(level + 1) .. "param(" .. table.concat(params, ", ") .. ")")
        end
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "LocalVarDecl" or statement.type == "AssignmentStmt" then
        if isCall(statement.init, "coroutine.create") then
            return self:coroutineCreate(statement, level)
        elseif isCall(statement.init, "coroutine.resume") then
            return self:coroutineResume({ statement.name }, statement.init, level)
        end
        return indent(level) .. "$" .. statement.name .. " = " .. self:expression(statement.init)
    elseif statement.type == "MultiLocalVarDecl" or statement.type == "MultiAssignmentStmt" then
        if not isCall(statement.init, "coroutine.resume") then
            error("PS1Transpiler Error: multiple assignment is supported only for coroutine.resume")
        end
        return self:coroutineResume(statement.names, statement.init, level)
    elseif statement.type == "IfStmt" then
        local output = { indent(level) .. "if (" .. self:expression(statement.condition) .. ") {" }
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        for _, elseifNode in ipairs(statement.elseifs or {}) do
            table.insert(output, indent(level) .. "} elseif (" .. self:expression(elseifNode.condition) .. ") {")
            for _, bodyStatement in ipairs(elseifNode.body) do
                table.insert(output, self:statement(bodyStatement, level + 1))
            end
        end
        if statement.elseBody then
            table.insert(output, indent(level) .. "} else {")
            for _, bodyStatement in ipairs(statement.elseBody) do
                table.insert(output, self:statement(bodyStatement, level + 1))
            end
        end
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "ReturnStmt" then
        return indent(level) .. "return " .. self:expression(statement.value)
    elseif statement.type == "ExprStmt" then
        if isCall(statement.expr, "coroutine.resume") then
            return self:coroutineResume({}, statement.expr, level)
        elseif statement.expr.type == "CallExpr" then
            return indent(level) .. self:command(statement.expr)
        end
    end
    error("PS1Transpiler Error: unsupported statement " .. tostring(statement.type))
end

function Generator:generate(program)
    local output = {}
    for _, statement in ipairs(program.body) do
        table.insert(output, self:statement(statement, 0))
    end
    return table.concat(output, "\n") .. "\n"
end

local Serializer = {}

function Serializer.serialize(targetAST)
    assert(targetAST and targetAST.type == "PS1Script", "PowerShell serializer expects a PS1Script AST")
    return Generator.new(targetAST):generate(targetAST.program)
end

PS1Transpiler.Serializer = Serializer
return PS1Transpiler
