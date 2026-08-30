local PS1Transpiler = { name = "ps1", extension = ".ps1" }
PS1Transpiler.__index = PS1Transpiler

local ScopeResolver = require("scope_resolver")
local StdlibAnalyzer = require("stdlib_analyzer")
local PS1Base = require("stdlib.powershell.base")
local PS1IO = require("stdlib.powershell.io")
local PS1Math = require("stdlib.powershell.math")
local PS1OS = require("stdlib.powershell.os")
local PS1String = require("stdlib.powershell.string")
local PS1Table = require("stdlib.powershell.table")

local STDLIBS = { PS1Base, PS1Math, PS1String, PS1IO, PS1OS, PS1Table }

local function stdlibFunction(name)
    for _, library in ipairs(STDLIBS) do
        if library.functions[name] then
            return library.functions[name]
        end
        if library.unsupported and library.unsupported[name] then
            error("PS1Transpiler Error: unsupported library call '" .. name .. "': " .. library.unsupported[name])
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
    local runtime = { call = false }
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
            visitExpression(node.left)
            visitExpression(node.right)
        elseif node.type == "UnaryExpr" then
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
                        error("PS1Transpiler Error: recursive functions with captured outer locals are not supported")
                    end
                    statement.closureId = #closures + 1
                    table.insert(closures, statement)
                    capturedFunctionNames[name] = true
                    runtime.call = true
                else
                    functionNames[name] = true
                end
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
            elseif statement.type == "TableAssignmentStmt" then
                visitExpression(statement.table)
                visitExpression(statement.key)
                visitExpression(statement.init)
            elseif
                statement.type == "NumericForStmt"
                or statement.type == "GenericForStmt"
                or statement.type == "WhileStmt"
                or statement.type == "RepeatStmt"
            then
                visitExpression(statement.startValue)
                visitExpression(statement.endValue)
                visitExpression(statement.stepValue)
                visitExpression(statement.iterator)
                visitExpression(statement.condition)
                visitStatements(statement.body)
            elseif statement.type == "DoStmt" then
                visitStatements(statement.body)
            else
                visitExpression(statement.init or statement.value or statement.expr)
            end
        end
    end

    visitStatements(program.body)
    return closures, functionNames, capturedFunctionNames, runtime
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
    ScopeResolver.resolve(luaAST)
    local closures, functionNames, capturedFunctionNames, runtime = collectMetadata(luaAST)
    local requiredStdlibs = StdlibAnalyzer.analyze(luaAST)
    local stdlibs = {}
    for _, library in ipairs(STDLIBS) do
        if requiredStdlibs[library.name] then
            table.insert(stdlibs, library)
        end
    end
    local workers = self:collectCoroutineWorkers(luaAST)
    runtime.coroutine = next(workers) ~= nil
    return {
        type = "PS1Script",
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

function Generator:command(node)
    local helper = stdlibFunction(node.callee)
    if node.callee:find("%.") and not helper then
        error("PS1Transpiler Error: unsupported library call '" .. node.callee .. "'")
    end
    local arguments = {}
    for _, argument in ipairs(node.args) do
        table.insert(arguments, self:expression(argument))
    end
    if node.callee == "print" then
        return "Write-Output" .. (#arguments > 0 and " " .. table.concat(arguments, " ") or "")
    end
    local callee = helper or node.resolvedCallee or node.callee
    if self.capturedFunctionNames[callee] then
        return "__luash_call $" .. callee .. " @(" .. table.concat(arguments, ", ") .. ")"
    elseif node.calleeKind == "function" or self.functionNames[callee] then
        return callee .. (#arguments > 0 and " " .. table.concat(arguments, " ") or "")
    elseif node.calleeIsLocal or callee:find("^__luash_local_") then
        return "__luash_call $" .. callee .. " @(" .. table.concat(arguments, ", ") .. ")"
    end
    return callee .. (#arguments > 0 and " " .. table.concat(arguments, " ") or "")
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
            local constant = stdlibConstant(node.name)
            if constant then
                return constant
            end
            error("PS1Transpiler Error: unsupported library value '" .. node.name .. "'")
        end
        local name = node.resolvedName or node.name
        if self.capturedFunctionNames[name] then
            return "$" .. name
        elseif node.bindingKind == "function" or self.functionNames[name] then
            return psQuote(name)
        end
        return "$" .. name
    elseif node.type == "TableConstructor" then
        local expressions = { "$__luash_table_value = __luash_table_new" }
        for _, field in ipairs(node.fields) do
            local present = not (field.value.type == "Literal" and field.value.value == nil)
            table.insert(
                expressions,
                "__luash_table_set $__luash_table_value "
                    .. psQuote(self:tableKeyType(field.key))
                    .. " "
                    .. self:expression(field.key)
                    .. " "
                    .. self:expression(field.value)
                    .. " "
                    .. (present and "$true" or "$false")
            )
        end
        table.insert(expressions, "$__luash_table_value")
        return "(& { " .. table.concat(expressions, "; ") .. " })"
    elseif node.type == "IndexExpr" then
        return "(__luash_table_get "
            .. self:expression(node.table)
            .. " "
            .. psQuote(self:tableKeyType(node.key))
            .. " "
            .. self:expression(node.key)
            .. ")"
    elseif node.type == "CallExpr" then
        if node.callee == "tostring" and #node.args == 1 then
            return "([string] " .. self:expression(node.args[1]) .. ")"
        end
        return "$(" .. self:command(node) .. ")"
    elseif node.type == "FunctionExpr" then
        return self:closureValue(node)
    elseif node.type == "UnaryExpr" then
        if node.operator == "-" then
            return "(-" .. self:expression(node.operand) .. ")"
        elseif node.operator == "not" then
            return "(-not " .. self:expression(node.operand) .. ")"
        elseif node.operator == "#" then
            return "(__luash_length " .. self:expression(node.operand) .. ")"
        end
    elseif node.type == "BinaryExpr" then
        if node.operator == "^" then
            return "[Math]::Pow(" .. self:expression(node.left) .. ", " .. self:expression(node.right) .. ")"
        elseif node.operator == ".." then
            return "([string] " .. self:expression(node.left) .. " + [string] " .. self:expression(node.right) .. ")"
        elseif node.operator == "or" then
            return "$(if ("
                .. self:expression(node.left)
                .. ") { "
                .. self:expression(node.left)
                .. " } else { "
                .. self:expression(node.right)
                .. " })"
        elseif node.operator == "and" then
            return "$(if ("
                .. self:expression(node.left)
                .. ") { "
                .. self:expression(node.right)
                .. " } else { "
                .. self:expression(node.left)
                .. " })"
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
        }
        local operator = operators[node.operator]
        if operator then
            return "(" .. self:expression(node.left) .. " " .. operator .. " " .. self:expression(node.right) .. ")"
        end
    end
    error("PS1Transpiler Error: unsupported expression " .. tostring(node.type))
end

function Generator:closureValue(node)
    local captures = {}
    for _, capture in ipairs(node.captures or {}) do
        local value
        if
            (capture.kind == "function" and not self.capturedFunctionNames[capture.resolvedName])
            or self.functionNames[capture.resolvedName]
        then
            value = psQuote(capture.resolvedName)
        else
            value = "$" .. capture.resolvedName
        end
        table.insert(captures, psQuote(capture.resolvedName) .. " = " .. value)
    end
    return "@{ Function = "
        .. psQuote("__luash_closure_" .. node.closureId)
        .. "; Captures = @{ "
        .. table.concat(captures, "; ")
        .. " } }"
end

function Generator:closure(node, level)
    local output = { indent(level) .. "function __luash_closure_" .. node.closureId .. " {" }
    local parameters = { "$__luash_closure_context" }
    for _, parameter in ipairs(node.resolvedParams or node.params) do
        table.insert(parameters, "$" .. parameter)
    end
    table.insert(output, indent(level + 1) .. "param(" .. table.concat(parameters, ", ") .. ")")
    for _, capture in ipairs(node.captures or {}) do
        table.insert(
            output,
            indent(level + 1)
                .. "$"
                .. capture.resolvedName
                .. " = $__luash_closure_context.Captures["
                .. psQuote(capture.resolvedName)
                .. "]"
        )
    end
    for _, bodyStatement in ipairs(node.body) do
        table.insert(output, self:statement(bodyStatement, level + 1))
    end
    table.insert(output, indent(level) .. "}")
    return table.concat(output, "\n")
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
        .. (statement.resolvedName or statement.name)
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
        if statement.closureId then
            return indent(level)
                .. "$"
                .. (statement.resolvedName or statement.name)
                .. " = "
                .. self:closureValue(statement)
        end
        local output = { indent(level) .. "function " .. (statement.resolvedName or statement.name) .. " {" }
        local resolvedParams = statement.resolvedParams or statement.params
        if #resolvedParams > 0 then
            local params = {}
            for _, parameter in ipairs(resolvedParams) do
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
            return self:coroutineResume({ statement.resolvedName or statement.name }, statement.init, level)
        end
        local name = statement.resolvedName or statement.name
        local prefix = statement.type == "AssignmentStmt"
                and not statement.bindingIsLocal
                and statement.functionDepth > 0
                and "$script:"
            or "$"
        local output = indent(level) .. prefix .. name .. " = " .. self:expression(statement.init)
        if statement.isCapturedAssignment then
            output = output
                .. "\n"
                .. indent(level)
                .. "$__luash_closure_context.Captures["
                .. psQuote(name)
                .. "] = $"
                .. name
        end
        return output
    elseif statement.type == "MultiLocalVarDecl" or statement.type == "MultiAssignmentStmt" then
        if not isCall(statement.init, "coroutine.resume") then
            error("PS1Transpiler Error: multiple assignment is supported only for coroutine.resume")
        end
        return self:coroutineResume(statement.resolvedNames or statement.names, statement.init, level)
    elseif statement.type == "TableAssignmentStmt" then
        local present = not (statement.init.type == "Literal" and statement.init.value == nil)
        return indent(level)
            .. "__luash_table_set "
            .. self:expression(statement.table)
            .. " "
            .. psQuote(self:tableKeyType(statement.key))
            .. " "
            .. self:expression(statement.key)
            .. " "
            .. self:expression(statement.init)
            .. " "
            .. (present and "$true" or "$false")
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
    elseif statement.type == "WhileStmt" then
        local output = { indent(level) .. "while (" .. self:expression(statement.condition) .. ") {" }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "RepeatStmt" then
        local output = { indent(level) .. "do {" }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level) .. "} until (" .. self:expression(statement.condition) .. ")")
        return table.concat(output, "\n")
    elseif statement.type == "NumericForStmt" then
        self.loopId = self.loopId + 1
        local id = self.loopId
        local valueName = "__luash_for_value_" .. id
        local limitName = "__luash_for_limit_" .. id
        local stepName = "__luash_for_step_" .. id
        local variableName = statement.resolvedName or statement.name
        local output = {
            indent(level) .. "$" .. valueName .. " = " .. self:expression(statement.startValue),
            indent(level) .. "$" .. limitName .. " = " .. self:expression(statement.endValue),
            indent(level) .. "$" .. stepName .. " = " .. self:expression(statement.stepValue),
            indent(level)
                .. "while ((($"
                .. stepName
                .. " -gt 0) -and ($"
                .. valueName
                .. " -le $"
                .. limitName
                .. ")) -or (($"
                .. stepName
                .. " -le 0) -and ($"
                .. valueName
                .. " -ge $"
                .. limitName
                .. "))) {",
            indent(level + 1) .. "$" .. variableName .. " = $" .. valueName,
        }
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level + 1) .. "$" .. valueName .. " += $" .. stepName)
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "GenericForStmt" then
        local iterator = statement.iterator
        if
            iterator.type ~= "CallExpr"
            or (iterator.callee ~= "pairs" and iterator.callee ~= "ipairs")
            or #iterator.args ~= 1
        then
            error("PS1Transpiler Error: generic for currently supports pairs(table) or ipairs(table)")
        end
        self.loopId = self.loopId + 1
        local itemName = "__luash_for_item_" .. self.loopId
        local collectionName = "__luash_for_collection_" .. self.loopId
        local collection = "$" .. collectionName
        local names = statement.resolvedNames or statement.names
        local output = {
            indent(level) .. collection .. " = " .. self:expression(iterator.args[1]),
        }
        if iterator.callee == "ipairs" then
            local indexName = "__luash_for_index_" .. self.loopId
            table.insert(
                output,
                indent(level)
                    .. "for ($"
                    .. indexName
                    .. " = 1; (__luash_table_contains "
                    .. collection
                    .. " 'n' $"
                    .. indexName
                    .. "); $"
                    .. indexName
                    .. "++) {"
            )
            if names[1] then
                table.insert(output, indent(level + 1) .. "$" .. names[1] .. " = $" .. indexName)
            end
            if names[2] then
                table.insert(
                    output,
                    indent(level + 1)
                        .. "$"
                        .. names[2]
                        .. " = __luash_table_get "
                        .. collection
                        .. " 'n' $"
                        .. indexName
                )
            end
        else
            table.insert(
                output,
                indent(level) .. "foreach ($" .. itemName .. " in @(" .. collection .. ".Entries.Keys)) {"
            )
            if names[1] then
                table.insert(
                    output,
                    indent(level + 1) .. "$" .. names[1] .. " = " .. collection .. ".Keys[$" .. itemName .. "]"
                )
            end
            if names[2] then
                table.insert(
                    output,
                    indent(level + 1) .. "$" .. names[2] .. " = " .. collection .. ".Entries[$" .. itemName .. "]"
                )
            end
        end
        for index = 3, #names do
            table.insert(output, indent(level + 1) .. "$" .. names[index] .. " = $null")
        end
        self.loopDepth = self.loopDepth + 1
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level + 1))
        end
        self.loopDepth = self.loopDepth - 1
        table.insert(output, indent(level) .. "}")
        return table.concat(output, "\n")
    elseif statement.type == "DoStmt" then
        local output = {}
        for _, bodyStatement in ipairs(statement.body) do
            table.insert(output, self:statement(bodyStatement, level))
        end
        return table.concat(output, "\n")
    elseif statement.type == "BreakStmt" then
        if self.loopDepth == 0 then
            error("PS1Transpiler Error: break must be inside a loop")
        end
        return indent(level) .. "break"
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

function Generator:callRuntime()
    return [=[function __luash_call {
    param($Callable, [object[]] $Arguments)
    if ($Callable -is [hashtable] -and $Callable.Function) {
        return & $Callable.Function $Callable @Arguments
    }
    return & $Callable @Arguments
}]=]
end

function Generator:generate(program)
    local output = {}
    if self.runtime.call then
        table.insert(output, self:callRuntime())
        table.insert(output, "")
    end
    for _, library in ipairs(self.stdlibs) do
        table.insert(output, library.source)
        table.insert(output, "")
    end
    for _, closure in ipairs(self.closures) do
        table.insert(output, self:closure(closure, 0))
        table.insert(output, "")
    end
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
