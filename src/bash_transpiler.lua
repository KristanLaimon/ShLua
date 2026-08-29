local BashTranspiler = { name = "bash", extension = ".sh" }
BashTranspiler.__index = BashTranspiler

local function isCall(node, name)
    return node and node.type == "CallExpr" and node.callee == name
end

local function shellQuote(value)
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
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

function BashTranspiler.new()
    return setmetatable({}, BashTranspiler)
end

function BashTranspiler:collectCoroutineWorkers(program)
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

function BashTranspiler:translate(luaAST)
    assert(luaAST and luaAST.type == "Program", "BashTranspiler expects a Program AST")
    return {
        type = "BashScript",
        program = luaAST,
        coroutineWorkers = self:collectCoroutineWorkers(luaAST),
    }
end

local Generator = {}
Generator.__index = Generator

function Generator.new(targetAST)
    return setmetatable({ workers = targetAST.coroutineWorkers }, Generator)
end

function Generator:arithmetic(node)
    if node.type == "Literal" and type(node.value) == "number" then
        return tostring(node.value)
    elseif node.type == "Identifier" then
        return node.name
    elseif node.type == "UnaryExpr" and node.operator == "-" then
        return "-(" .. self:arithmetic(node.operand) .. ")"
    elseif node.type == "BinaryExpr" then
        local operators = { ["+"] = "+", ["-"] = "-", ["*"] = "*", ["/"] = "/", ["%"] = "%", ["^"] = "**" }
        local operator = operators[node.operator]
        if operator then
            return "(" .. self:arithmetic(node.left) .. " " .. operator .. " " .. self:arithmetic(node.right) .. ")"
        end
    end
    return self:expression(node):gsub('^"', ""):gsub('"$', "")
end

function Generator:condition(node)
    if node.type == "Literal" and type(node.value) == "boolean" then
        return node.value and "true" or "false"
    elseif node.type == "Identifier" then
        local value = self:expression(node)
        return "[ -n " .. value .. " ] && [ " .. value .. " != 'false' ]"
    elseif node.type == "UnaryExpr" and node.operator == "not" then
        return "! { " .. self:condition(node.operand) .. "; }"
    elseif node.type == "BinaryExpr" then
        if node.operator == "and" then
            return "{ " .. self:condition(node.left) .. "; } && { " .. self:condition(node.right) .. "; }"
        elseif node.operator == "or" then
            return "{ " .. self:condition(node.left) .. "; } || { " .. self:condition(node.right) .. "; }"
        end
        local operators = {
            ["=="] = "=",
            ["~="] = "!=",
            ["<"] = "-lt",
            [">"] = "-gt",
            ["<="] = "-le",
            [">="] = "-ge",
        }
        if operators[node.operator] then
            return "[ "
                .. self:expression(node.left)
                .. " "
                .. operators[node.operator]
                .. " "
                .. self:expression(node.right)
                .. " ]"
        end
    end
    return "[ -n " .. self:expression(node) .. " ]"
end

function Generator:command(node)
    if node.callee:find("%.") then
        error("BashTranspiler Error: unsupported library call '" .. node.callee .. "'")
    end
    local arguments = {}
    for _, argument in ipairs(node.args) do
        table.insert(arguments, self:expression(argument))
    end
    if node.callee == "print" then
        if #arguments == 0 then
            return "printf '\\n'"
        end
        local formats = {}
        for _ = 1, #arguments do
            table.insert(formats, "%s")
        end
        return "printf '" .. table.concat(formats, "\\t") .. "\\n' " .. table.concat(arguments, " ")
    end
    return node.callee .. (#arguments > 0 and " " .. table.concat(arguments, " ") or "")
end

function Generator:expression(node)
    if node.type == "Literal" then
        if node.value == nil then
            return "''"
        elseif type(node.value) == "number" then
            return tostring(node.value)
        elseif type(node.value) == "boolean" then
            return shellQuote(node.value and "true" or "false")
        end
        return shellQuote(node.value)
    elseif node.type == "Identifier" then
        if node.name:find("%.") then
            error("BashTranspiler Error: dotted values are supported only as calls")
        end
        return '"${' .. node.name .. '}"'
    elseif node.type == "CallExpr" then
        return "$(" .. self:command(node) .. ")"
    elseif node.type == "UnaryExpr" then
        if node.operator == "-" then
            return "$(( " .. self:arithmetic(node) .. " ))"
        elseif node.operator == "#" and node.operand.type == "Identifier" then
            return '"${#' .. node.operand.name .. '}"'
        elseif node.operator == "not" then
            return "$(if " .. self:condition(node) .. "; then printf true; else printf false; fi)"
        end
    elseif node.type == "BinaryExpr" then
        if node.operator == ".." then
            return self:expression(node.left) .. self:expression(node.right)
        elseif
            node.operator == "+"
            or node.operator == "-"
            or node.operator == "*"
            or node.operator == "/"
            or node.operator == "%"
            or node.operator == "^"
        then
            return "$(( " .. self:arithmetic(node) .. " ))"
        end
        return "$(if " .. self:condition(node) .. "; then printf true; else printf false; fi)"
    end
    error("BashTranspiler Error: unsupported expression " .. tostring(node.type))
end

function Generator:coroutineWorker(statement, level)
    local output = { indent(level) .. "__luash_coroutine_" .. statement.name .. "() {" }
    table.insert(output, indent(level + 1) .. 'local __handle="$1"')
    table.insert(output, indent(level + 1) .. 'local __state_var="${__handle}__state"')
    table.insert(output, indent(level + 1) .. 'local __state="${!__state_var}"')
    table.insert(output, indent(level + 1) .. "__state=$((__state + 1))")
    table.insert(output, indent(level + 1) .. 'printf -v "$__state_var" \'%s\' "$__state"')
    table.insert(output, indent(level + 1) .. 'case "$__state" in')

    local state = 0
    local returnValue = { type = "Literal", value = nil }
    for _, bodyStatement in ipairs(statement.body) do
        if bodyStatement.type == "ExprStmt" then
            state = state + 1
            local value = bodyStatement.expr.args[1] or { type = "Literal", value = nil }
            table.insert(output, indent(level + 2) .. state .. ")")
            table.insert(output, indent(level + 3) .. "__luash_coroutine_ok='true'")
            table.insert(output, indent(level + 3) .. "__luash_coroutine_value=" .. self:expression(value))
            table.insert(output, indent(level + 3) .. ";;")
        else
            returnValue = bodyStatement.value
        end
    end

    state = state + 1
    table.insert(output, indent(level + 2) .. state .. ")")
    table.insert(output, indent(level + 3) .. "__luash_coroutine_ok='true'")
    table.insert(output, indent(level + 3) .. "__luash_coroutine_value=" .. self:expression(returnValue))
    table.insert(output, indent(level + 3) .. ";;")
    table.insert(output, indent(level + 2) .. "*)")
    table.insert(output, indent(level + 3) .. "__luash_coroutine_ok='false'")
    table.insert(output, indent(level + 3) .. "__luash_coroutine_value='cannot resume dead coroutine'")
    table.insert(output, indent(level + 3) .. ";;")
    table.insert(output, indent(level + 1) .. "esac")
    table.insert(output, indent(level) .. "}")
    return table.concat(output, "\n")
end

function Generator:coroutineCreate(statement, level, inFunction)
    local prefix = indent(level)
    local modifier = inFunction and statement.type == "LocalVarDecl" and "local " or ""
    local worker = statement.init.args[1].name
    return table.concat({
        prefix .. modifier .. statement.name .. "=" .. shellQuote(statement.name),
        prefix .. statement.name .. "__worker=" .. shellQuote(worker),
        prefix .. statement.name .. "__state=0",
    }, "\n")
end

function Generator:coroutineResume(names, call, level, inFunction, isLocal)
    if #call.args ~= 1 or call.args[1].type ~= "Identifier" then
        error("Coroutine Error: coroutine.resume expects one coroutine variable")
    end
    if #names > 2 then
        error("Coroutine Error: alpha resume returns only success and one value")
    end
    local output = { indent(level) .. "__luash_coroutine_resume " .. self:expression(call.args[1]) }
    local values = { '"$__luash_coroutine_ok"', '"$__luash_coroutine_value"' }
    for index, name in ipairs(names) do
        local modifier = inFunction and isLocal and "local " or ""
        table.insert(output, indent(level) .. modifier .. name .. "=" .. values[index])
    end
    return table.concat(output, "\n")
end

function Generator:statement(statement, level, inFunction)
    if statement.type == "FunctionDecl" then
        if self.workers[statement.name] then
            return self:coroutineWorker(statement, level)
        end
        local output = { indent(level) .. statement.name .. "() {" }
        for index, parameter in ipairs(statement.params) do
            table.insert(output, indent(level + 1) .. "local " .. parameter .. '="${' .. index .. '}"')
        end
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, true))
        end
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "LocalVarDecl" or statement.type == "AssignmentStmt" then
        if isCall(statement.init, "coroutine.create") then
            return self:coroutineCreate(statement, level, inFunction)
        elseif isCall(statement.init, "coroutine.resume") then
            return self:coroutineResume(
                { statement.name },
                statement.init,
                level,
                inFunction,
                statement.type == "LocalVarDecl"
            )
        end
        local modifier = inFunction and statement.type == "LocalVarDecl" and "local " or ""
        return indent(level) .. modifier .. statement.name .. "=" .. self:expression(statement.init)
    elseif statement.type == "MultiLocalVarDecl" or statement.type == "MultiAssignmentStmt" then
        if not isCall(statement.init, "coroutine.resume") then
            error("BashTranspiler Error: multiple assignment is supported only for coroutine.resume")
        end
        return self:coroutineResume(
            statement.names,
            statement.init,
            level,
            inFunction,
            statement.type == "MultiLocalVarDecl"
        )
    elseif statement.type == "IfStmt" then
        local output = { indent(level) .. "if " .. self:condition(statement.condition) .. "; then" }
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
        end
        for _, elseifNode in ipairs(statement.elseifs or {}) do
            table.insert(output, indent(level) .. "elif " .. self:condition(elseifNode.condition) .. "; then")
            for _, bodyStatement in ipairs(elseifNode.body) do
                table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
            end
        end
        if statement.elseBody then
            table.insert(output, indent(level) .. "else")
            for _, bodyStatement in ipairs(statement.elseBody) do
                table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
            end
        end
        table.insert(output, indent(level) .. "fi")
        return table.concat(output, "\n")
    elseif statement.type == "ReturnStmt" then
        return indent(level)
            .. "printf '%s\\n' "
            .. self:expression(statement.value)
            .. "\n"
            .. indent(level)
            .. "return 0"
    elseif statement.type == "ExprStmt" then
        if isCall(statement.expr, "coroutine.resume") then
            return self:coroutineResume({}, statement.expr, level, inFunction, false)
        elseif statement.expr.type == "CallExpr" then
            return indent(level) .. self:command(statement.expr)
        end
    end
    error("BashTranspiler Error: unsupported statement " .. tostring(statement.type))
end

function Generator:runtime()
    return [[__luash_coroutine_ok=''
__luash_coroutine_value=''
__luash_coroutine_resume() {
    local __handle="$1"
    local __worker_var="${__handle}__worker"
    local __worker="${!__worker_var}"
    if [ -z "$__worker" ]; then
        __luash_coroutine_ok='false'
        __luash_coroutine_value='invalid coroutine handle'
        return 0
    fi
    "__luash_coroutine_${__worker}" "$__handle"
}]]
end

function Generator:generate(program)
    local output = { "#!/usr/bin/env bash", "" }
    if next(self.workers) then
        table.insert(output, self:runtime())
        table.insert(output, "")
    end
    for _, statement in ipairs(program.body) do
        table.insert(output, self:statement(statement, 0, false))
    end
    return table.concat(output, "\n") .. "\n"
end

local Serializer = {}

function Serializer.serialize(targetAST)
    assert(targetAST and targetAST.type == "BashScript", "Bash serializer expects a BashScript AST")
    return Generator.new(targetAST):generate(targetAST.program)
end

BashTranspiler.Serializer = Serializer
return BashTranspiler
