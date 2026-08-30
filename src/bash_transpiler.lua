local BashTranspiler = { name = "bash", extension = ".sh" }
BashTranspiler.__index = BashTranspiler

local ScopeResolver = require("scope_resolver")
local StdlibAnalyzer = require("stdlib_analyzer")
local StdlibSelector = require("stdlib_selector")
local BashBase = require("stdlib.bash.base")
local BashIO = require("stdlib.bash.io")
local BashMath = require("stdlib.bash.math")
local BashOS = require("stdlib.bash.os")
local BashString = require("stdlib.bash.string")
local BashTable = require("stdlib.bash.table")

local STDLIBS = { BashBase, BashMath, BashString, BashIO, BashOS, BashTable }

local function stdlibFunction(name)
    for _, library in ipairs(STDLIBS) do
        if library.functions[name] then
            return library.functions[name]
        end
        if library.unsupported and library.unsupported[name] then
            error("BashTranspiler Error: unsupported library call '" .. name .. "': " .. library.unsupported[name])
        end
    end
    return nil
end

local function stdlibConstant(name)
    for _, library in ipairs(STDLIBS) do
        if library.constants and library.constants[name] then
            return library.constants[name]
        end
    end
    return nil
end

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
        elseif
            statement.type == "NumericForStmt"
            or statement.type == "GenericForStmt"
            or statement.type == "WhileStmt"
            or statement.type == "RepeatStmt"
            or statement.type == "DoStmt"
        then
            validateCoroutinePlacement(statement.body, true)
        end
    end
end

local function collectMetadata(program)
    local closures = {}
    local functionNames = {}
    local capturedFunctionNames = {}
    local runtime = { arithmetic = false, call = false }
    local visitExpression
    local visitStatements

    visitExpression = function(node)
        if not node then
            return
        elseif node.type == "FunctionExpr" then
            node.closureId = #closures + 1
            table.insert(closures, node)
            runtime.call = true
            visitStatements(node.body)
        elseif node.type == "BinaryExpr" then
            if
                node.operator == "+"
                or node.operator == "-"
                or node.operator == "*"
                or node.operator == "/"
                or node.operator == "%"
                or node.operator == "^"
            then
                runtime.arithmetic = true
            end
            visitExpression(node.left)
            visitExpression(node.right)
        elseif node.type == "UnaryExpr" then
            if
                node.operator == "-" and not (node.operand.type == "Literal" and type(node.operand.value) == "number")
            then
                runtime.arithmetic = true
            end
            visitExpression(node.operand)
        elseif node.type == "IndexExpr" then
            visitExpression(node.table)
            visitExpression(node.key)
        elseif node.type == "TableConstructor" then
            for _, field in ipairs(node.fields) do
                visitExpression(field.key)
                visitExpression(field.value)
            end
        elseif node.type == "CallExpr" then
            if node.callee == "table.sort" and #node.args == 2 then
                runtime.call = true
            end
            for _, argument in ipairs(node.args) do
                visitExpression(argument)
            end
        end
    end

    visitStatements = function(statements)
        for _, statement in ipairs(statements) do
            if statement.type == "FunctionDecl" then
                local name = statement.resolvedName or statement.name
                if #(statement.captures or {}) > 0 then
                    if statement.recursive then
                        error("BashTranspiler Error: recursive functions with captured outer locals are not supported")
                    end
                    statement.closureId = #closures + 1
                    table.insert(closures, statement)
                    capturedFunctionNames[name] = true
                    runtime.call = true
                else
                    functionNames[name] = true
                end
                visitStatements(statement.body)
            elseif statement.type == "LocalVarDecl" or statement.type == "AssignmentStmt" then
                visitExpression(statement.init)
            elseif statement.type == "MultiLocalVarDecl" or statement.type == "MultiAssignmentStmt" then
                visitExpression(statement.init)
            elseif statement.type == "TableAssignmentStmt" then
                visitExpression(statement.table)
                visitExpression(statement.key)
                visitExpression(statement.init)
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
            else
                visitExpression(statement.value or statement.expr)
            end
        end
    end

    visitStatements(program.body)
    return closures, functionNames, capturedFunctionNames, runtime
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
    ScopeResolver.resolve(luaAST)
    local closures, functionNames, capturedFunctionNames, runtime = collectMetadata(luaAST)
    local requiredStdlibs = StdlibAnalyzer.analyze(luaAST)
    local stdlibs = {}
    for _, library in ipairs(STDLIBS) do
        if requiredStdlibs[library.name] then
            table.insert(stdlibs, { library = library, requirements = requiredStdlibs[library.name] })
        end
    end
    local workers = self:collectCoroutineWorkers(luaAST)
    runtime.coroutine = next(workers) ~= nil
    return {
        type = "BashScript",
        program = luaAST,
        coroutineWorkers = workers,
        closures = closures,
        functionNames = functionNames,
        capturedFunctionNames = capturedFunctionNames,
        stdlibs = stdlibs,
        runtime = runtime,
    }
end

local Generator = {}
Generator.__index = Generator

function Generator.new(targetAST)
    return setmetatable({
        workers = targetAST.coroutineWorkers,
        closures = targetAST.closures,
        functionNames = targetAST.functionNames,
        capturedFunctionNames = targetAST.capturedFunctionNames,
        stdlibs = targetAST.stdlibs,
        runtime = targetAST.runtime,
        loopId = 0,
        loopDepth = 0,
    }, Generator)
end

function Generator:identifierValue(name, kind)
    if self.capturedFunctionNames[name] then
        return '"${' .. name .. '}"'
    elseif kind == "function" or self.functionNames[name] then
        return shellQuote(name)
    end
    return '"${' .. name .. '}"'
end

function Generator:tableKeyType(node)
    local valueType = node.staticType or (node.type == "Literal" and (node.value == nil and "nil" or type(node.value)))
    if valueType == "nil" then
        return "z"
    elseif valueType == "number" then
        return "n"
    elseif valueType == "boolean" then
        return "b"
    elseif valueType == "string" then
        return "s"
    end
    return ""
end

function Generator:arithmetic(node)
    if node.type == "Literal" and type(node.value) == "number" then
        return tostring(node.value)
    elseif node.type == "Identifier" then
        return node.resolvedName or node.name
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
    local helper = stdlibFunction(node.callee)
    if node.callee:find("%.") and not helper then
        error("BashTranspiler Error: unsupported library call '" .. node.callee .. "'")
    end
    local arguments = {}
    for _, argument in ipairs(node.args) do
        if node.callee == "print" and argument.type == "Literal" and argument.value == nil then
            table.insert(arguments, "'nil'")
        else
            table.insert(arguments, self:expression(argument))
        end
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
    local callee = helper or node.resolvedCallee or node.callee
    local suffix = #arguments > 0 and " " .. table.concat(arguments, " ") or ""
    if self.capturedFunctionNames[callee] then
        return "__luash_call " .. self:identifierValue(callee, node.calleeKind) .. suffix
    elseif node.calleeKind == "function" or self.functionNames[callee] then
        return callee .. suffix
    elseif node.calleeIsLocal or callee:find("^__luash_local_") then
        return "__luash_call " .. self:identifierValue(callee, node.calleeKind) .. suffix
    end
    return callee .. suffix
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
            local constant = stdlibConstant(node.name)
            if constant then
                return constant
            end
            error("BashTranspiler Error: unsupported library value '" .. node.name .. "'")
        end
        return self:identifierValue(node.resolvedName or node.name, node.bindingKind)
    elseif node.type == "TableConstructor" then
        local arguments = {}
        for _, field in ipairs(node.fields) do
            local present = not (field.value.type == "Literal" and field.value.value == nil)
            table.insert(arguments, shellQuote(self:tableKeyType(field.key)))
            table.insert(arguments, self:expression(field.key))
            table.insert(arguments, self:expression(field.value))
            table.insert(arguments, shellQuote(present and "1" or "0"))
        end
        local suffix = #arguments > 0 and " " .. table.concat(arguments, " ") or ""
        return '"$(__luash_table_new' .. suffix .. ')"'
    elseif node.type == "IndexExpr" then
        return '"$(__luash_table_get '
            .. self:expression(node.table)
            .. " "
            .. shellQuote(self:tableKeyType(node.key))
            .. " "
            .. self:expression(node.key)
            .. ')"'
    elseif node.type == "CallExpr" then
        if
            (node.callee == "tostring" or node.callee == "type")
            and #node.args == 1
            and node.args[1].type == "Literal"
            and node.args[1].value == nil
        then
            return "'nil'"
        end
        return '"$(' .. self:command(node) .. ')"'
    elseif node.type == "FunctionExpr" then
        return self:closureValue(node)
    elseif node.type == "UnaryExpr" then
        if node.operator == "-" then
            if node.operand.type == "Literal" and type(node.operand.value) == "number" then
                return tostring(-node.operand.value)
            end
            return '"$(__luash_arithmetic 0 ' .. shellQuote("-") .. " " .. self:expression(node.operand) .. ')"'
        elseif node.operator == "#" then
            return '"$(__luash_length ' .. self:expression(node.operand) .. ')"'
        elseif node.operator == "not" then
            return "$(if " .. self:condition(node) .. "; then printf true; else printf false; fi)"
        end
    elseif node.type == "BinaryExpr" then
        if node.operator == ".." then
            return self:expression(node.left) .. self:expression(node.right)
        elseif node.operator == "or" then
            return '"$(if '
                .. self:condition(node.left)
                .. "; then printf '%s' "
                .. self:expression(node.left)
                .. "; else printf '%s' "
                .. self:expression(node.right)
                .. '; fi)"'
        elseif node.operator == "and" then
            return '"$(if '
                .. self:condition(node.left)
                .. "; then printf '%s' "
                .. self:expression(node.right)
                .. "; else printf '%s' "
                .. self:expression(node.left)
                .. '; fi)"'
        elseif
            node.operator == "+"
            or node.operator == "-"
            or node.operator == "*"
            or node.operator == "/"
            or node.operator == "%"
            or node.operator == "^"
        then
            return '"$(__luash_arithmetic '
                .. self:expression(node.left)
                .. " "
                .. shellQuote(node.operator)
                .. " "
                .. self:expression(node.right)
                .. ')"'
        end
        return "$(if " .. self:condition(node) .. "; then printf true; else printf false; fi)"
    end
    error("BashTranspiler Error: unsupported expression " .. tostring(node.type))
end

function Generator:closureValue(node)
    local value = '"__luash_closure_' .. node.closureId
    for _, capture in ipairs(node.captures or {}) do
        value = value .. "${__luash_closure_separator}"
        if
            (capture.kind == "function" and not self.capturedFunctionNames[capture.resolvedName])
            or self.functionNames[capture.resolvedName]
        then
            value = value .. capture.resolvedName
        else
            value = value .. "${" .. capture.resolvedName .. "}"
        end
    end
    return value .. '"'
end

function Generator:closure(node, level)
    local output = { indent(level) .. "__luash_closure_" .. node.closureId .. "() {" }
    for _, capture in ipairs(node.captures or {}) do
        table.insert(output, indent(level + 1) .. "local " .. capture.resolvedName .. '="$1"')
        table.insert(output, indent(level + 1) .. "shift")
    end
    for _, parameter in ipairs(node.resolvedParams or node.params) do
        table.insert(output, indent(level + 1) .. "local " .. parameter .. '="$1"')
        table.insert(output, indent(level + 1) .. "shift")
    end
    for _, bodyStatement in ipairs(node.body) do
        table.insert(output, self:statement(bodyStatement, level + 1, true))
    end
    table.insert(output, indent(level) .. "}")
    return table.concat(output, "\n")
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
    local name = statement.resolvedName or statement.name
    return table.concat({
        prefix .. modifier .. name .. "=" .. shellQuote(name),
        prefix .. name .. "__worker=" .. shellQuote(worker),
        prefix .. name .. "__state=0",
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
        if statement.closureId then
            local modifier = inFunction and statement.isLocal and "local " or ""
            return indent(level)
                .. modifier
                .. (statement.resolvedName or statement.name)
                .. "="
                .. self:closureValue(statement)
        end
        local functionName = statement.resolvedName or statement.name
        local output = { indent(level) .. functionName .. "() {" }
        for index, parameter in ipairs(statement.resolvedParams or statement.params) do
            table.insert(output, indent(level + 1) .. "local " .. parameter .. '="${' .. index .. '}"')
        end
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, true))
        end
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "LocalVarDecl" or statement.type == "AssignmentStmt" then
        if statement.isCapturedAssignment then
            error("BashTranspiler Error: assignment to a captured closure variable is not supported")
        end
        if isCall(statement.init, "coroutine.create") then
            return self:coroutineCreate(statement, level, inFunction)
        elseif isCall(statement.init, "coroutine.resume") then
            return self:coroutineResume(
                { statement.resolvedName or statement.name },
                statement.init,
                level,
                inFunction,
                statement.type == "LocalVarDecl"
            )
        end
        local modifier = inFunction and statement.type == "LocalVarDecl" and "local " or ""
        return indent(level)
            .. modifier
            .. (statement.resolvedName or statement.name)
            .. "="
            .. self:expression(statement.init)
    elseif statement.type == "MultiLocalVarDecl" or statement.type == "MultiAssignmentStmt" then
        if not isCall(statement.init, "coroutine.resume") then
            error("BashTranspiler Error: multiple assignment is supported only for coroutine.resume")
        end
        return self:coroutineResume(
            statement.resolvedNames or statement.names,
            statement.init,
            level,
            inFunction,
            statement.type == "MultiLocalVarDecl"
        )
    elseif statement.type == "TableAssignmentStmt" then
        local present = not (statement.init.type == "Literal" and statement.init.value == nil)
        return indent(level)
            .. "__luash_table_set "
            .. self:expression(statement.table)
            .. " "
            .. shellQuote(self:tableKeyType(statement.key))
            .. " "
            .. self:expression(statement.key)
            .. " "
            .. self:expression(statement.init)
            .. " "
            .. shellQuote(present and "1" or "0")
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
    elseif statement.type == "WhileStmt" then
        local output = { indent(level) .. "while " .. self:condition(statement.condition) .. "; do" }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level) .. "done")
        return table.concat(output, "\n")
    elseif statement.type == "RepeatStmt" then
        local output = { indent(level) .. "while :; do" }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
        end
        table.insert(output, indent(level + 1) .. "if " .. self:condition(statement.condition) .. "; then")
        table.insert(output, indent(level + 2) .. "break")
        table.insert(output, indent(level + 1) .. "fi")
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level) .. "done")
        return table.concat(output, "\n")
    elseif statement.type == "NumericForStmt" then
        self.loopId = self.loopId + 1
        local id = self.loopId
        local valueName = "__luash_for_value_" .. id
        local limitName = "__luash_for_limit_" .. id
        local stepName = "__luash_for_step_" .. id
        local variableName = statement.resolvedName or statement.name
        local modifier = inFunction and "local " or ""
        local output = {
            indent(level) .. modifier .. valueName .. "=$(( " .. self:arithmetic(statement.startValue) .. " ))",
            indent(level) .. modifier .. limitName .. "=$(( " .. self:arithmetic(statement.endValue) .. " ))",
            indent(level) .. modifier .. stepName .. "=$(( " .. self:arithmetic(statement.stepValue) .. " ))",
            indent(level)
                .. 'while { [ "$'
                .. stepName
                .. '" -gt 0 ] && [ "$'
                .. valueName
                .. '" -le "$'
                .. limitName
                .. '" ]; } || { [ "$'
                .. stepName
                .. '" -le 0 ] && [ "$'
                .. valueName
                .. '" -ge "$'
                .. limitName
                .. '" ]; }; do',
            indent(level + 1) .. modifier .. variableName .. '="$' .. valueName .. '"',
        }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level + 1) .. valueName .. "=$(($" .. valueName .. " + $" .. stepName .. "))")
        table.insert(output, indent(level) .. "done")
        return table.concat(output, "\n")
    elseif statement.type == "GenericForStmt" then
        local iterator = statement.iterator
        if
            iterator.type ~= "CallExpr"
            or (iterator.callee ~= "pairs" and iterator.callee ~= "ipairs")
            or #iterator.args ~= 1
        then
            error("BashTranspiler Error: generic for currently supports pairs(table) or ipairs(table)")
        end
        self.loopId = self.loopId + 1
        local indexName = "__luash_for_index_" .. self.loopId
        local collectionName = "__luash_for_collection_" .. self.loopId
        local countName = "__luash_for_count_" .. self.loopId
        local names = statement.resolvedNames or statement.names
        local modifier = inFunction and "local " or ""
        local output = { indent(level) .. modifier .. collectionName .. "=" .. self:expression(iterator.args[1]) }
        if iterator.callee == "ipairs" then
            table.insert(output, indent(level) .. modifier .. indexName .. "=1")
            table.insert(
                output,
                indent(level) .. 'while __luash_table_contains "$' .. collectionName .. '" n "$' .. indexName .. '"; do'
            )
            if names[1] then
                table.insert(output, indent(level + 1) .. modifier .. names[1] .. '="$' .. indexName .. '"')
            end
            if names[2] then
                table.insert(
                    output,
                    indent(level + 1)
                        .. modifier
                        .. names[2]
                        .. '="$(__luash_table_get "$'
                        .. collectionName
                        .. '" n "$'
                        .. indexName
                        .. '")"'
                )
            end
            for index = 3, #names do
                table.insert(output, indent(level + 1) .. modifier .. names[index] .. "=''")
            end
            self.loopDepth = self.loopDepth + 1
            for _, bodyStatement in ipairs(statement.body) do
                table.insert(output, self:statement(bodyStatement, level + 1, inFunction))
            end
            self.loopDepth = self.loopDepth - 1
            table.insert(output, indent(level + 1) .. indexName .. "=$(($" .. indexName .. " + 1))")
            table.insert(output, indent(level) .. "done")
        else
            table.insert(output, indent(level) .. modifier .. countName .. '="$(<"$' .. collectionName .. '/count")"')
            table.insert(output, indent(level) .. modifier .. indexName .. "=1")
            table.insert(output, indent(level) .. 'while [ "$' .. indexName .. '" -le "$' .. countName .. '" ]; do')
            table.insert(
                output,
                indent(level + 1)
                    .. 'if __luash_table_entry_exists "$'
                    .. collectionName
                    .. '" "$'
                    .. indexName
                    .. '"; then'
            )
            if names[1] then
                table.insert(
                    output,
                    indent(level + 2)
                        .. modifier
                        .. names[1]
                        .. '="$(__luash_table_entry_key "$'
                        .. collectionName
                        .. '" "$'
                        .. indexName
                        .. '")"'
                )
            end
            if names[2] then
                table.insert(
                    output,
                    indent(level + 2)
                        .. modifier
                        .. names[2]
                        .. '="$(__luash_table_entry_value "$'
                        .. collectionName
                        .. '" "$'
                        .. indexName
                        .. '")"'
                )
            end
            for index = 3, #names do
                table.insert(output, indent(level + 2) .. modifier .. names[index] .. "=''")
            end
            self.loopDepth = self.loopDepth + 1
            for _, bodyStatement in ipairs(statement.body) do
                table.insert(output, self:statement(bodyStatement, level + 2, inFunction))
            end
            self.loopDepth = self.loopDepth - 1
            table.insert(output, indent(level + 1) .. "fi")
            table.insert(output, indent(level + 1) .. indexName .. "=$(($" .. indexName .. " + 1))")
            table.insert(output, indent(level) .. "done")
        end
        return table.concat(output, "\n")
    elseif statement.type == "DoStmt" then
        local output = {}
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level, inFunction))
        end
        return table.concat(output, "\n")
    elseif statement.type == "BreakStmt" then
        if self.loopDepth == 0 then
            error("BashTranspiler Error: break must be inside a loop")
        end
        return indent(level) .. "break"
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

function Generator:arithmeticRuntime()
    return [[__luash_arithmetic() {
    LC_ALL=C awk -v left="$1" -v operator="$2" -v right="$3" '
        BEGIN {
            if (operator == "+") result = left + right
            else if (operator == "-") result = left - right
            else if (operator == "*") result = left * right
            else if (operator == "/") result = left / right
            else if (operator == "%") result = left % right
            else if (operator == "^") result = left ^ right
            printf "%.15g\n", result
        }
    ' </dev/null
}]]
end

function Generator:callRuntime()
    return [[__luash_closure_separator="$(printf '\034')"
__luash_call() {
    local __luash_callable="$1"
    shift
    local __luash_call_args=("$@")
    case "$__luash_callable" in
        __luash_closure_*)
            local __luash_old_ifs="$IFS"
            IFS="$__luash_closure_separator"
            local __luash_closure_parts=()
            read -r -a __luash_closure_parts <<< "$__luash_callable"
            IFS="$__luash_old_ifs"
            "${__luash_closure_parts[0]}" "${__luash_closure_parts[@]:1}" "${__luash_call_args[@]}"
            ;;
        *)
            "$__luash_callable" "${__luash_call_args[@]}"
            ;;
    esac
}]]
end

function Generator:coroutineRuntime()
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
    if self.runtime.arithmetic then
        table.insert(output, self:arithmeticRuntime())
        table.insert(output, "")
    end
    if self.runtime.call then
        table.insert(output, self:callRuntime())
        table.insert(output, "")
    end
    if self.runtime.coroutine then
        table.insert(output, self:coroutineRuntime())
        table.insert(output, "")
    end
    for _, selected in ipairs(self.stdlibs) do
        table.insert(output, StdlibSelector.render(selected.library, selected.requirements, "bash"))
        table.insert(output, "")
    end
    for _, closure in ipairs(self.closures) do
        table.insert(output, self:closure(closure, 0))
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
