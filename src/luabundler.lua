-- Flattens supported Lua require declarations into one source string before transpilation.

local Lexer = require("lexer")

local LuaBundler = {}

local STANDARD_MODULES = {
    coroutine = true,
    io = true,
    math = true,
    os = true,
    string = true,
    table = true,
}

local function readFile(path)
    local file, err = io.open(path, "rb")
    if not file then
        error("LuaBundler Error: cannot read module '" .. path .. "': " .. tostring(err))
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function pathDirectory(path)
    return path:match("^(.*)[/\\]") or "."
end

local function joinPath(directory, filename)
    local separator = package.config:sub(1, 1)
    if directory == "" or directory == "." then
        return filename
    end
    return directory .. separator .. filename
end

local function fileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

local function moduleCandidates(moduleName, rootDirectory)
    if not moduleName:match("^[%a_][%w_%.]*$") then
        error("LuaBundler Error: unsupported module name '" .. moduleName .. "'")
    end
    local relative = moduleName:gsub("%.", "/")
    return {
        joinPath(rootDirectory, relative .. ".lua"),
        joinPath(rootDirectory, relative .. "/init.lua"),
    }
end

local function resolveModule(moduleName, rootDirectory)
    for _, path in ipairs(moduleCandidates(moduleName, rootDirectory)) do
        if fileExists(path) then
            return path
        end
    end
    error("LuaBundler Error: cannot resolve local module '" .. moduleName .. "' from '" .. rootDirectory .. "'")
end

local function lineOffsets(source)
    local offsets = { 1 }
    local position = 1
    while true do
        local newline = source:find("\n", position, true)
        if not newline then
            break
        end
        table.insert(offsets, newline + 1)
        position = newline + 1
    end
    return offsets
end

local function tokenOffset(offsets, token)
    return offsets[token.line] + token.column - 1
end

local function isValue(token, tokenType, value)
    return token and token.type == tokenType and token.value == value
end

local function requireAt(tokens, position)
    if not isValue(tokens[position], "IDENTIFIER", "require") then
        return nil
    end
    if not isValue(tokens[position + 1], "OPERATOR", "(") then
        return nil
    end
    local module = tokens[position + 2]
    if not module or module.type ~= "STRING" or not isValue(tokens[position + 3], "OPERATOR", ")") then
        return nil
    end
    return module.value, position + 3
end

local function requireDeclarations(source)
    local tokens = Lexer.new(source):tokenize()
    local offsets = lineOffsets(source)
    local declarations = {}
    local position = 1

    while position <= #tokens do
        local moduleName
        local closePosition
        local startPosition
        if
            isValue(tokens[position], "KEYWORD", "local")
            and tokens[position + 1]
            and tokens[position + 1].type == "IDENTIFIER"
            and isValue(tokens[position + 2], "OPERATOR", "=")
        then
            moduleName, closePosition = requireAt(tokens, position + 3)
            startPosition = position
        else
            moduleName, closePosition = requireAt(tokens, position)
            startPosition = position
        end

        if moduleName then
            table.insert(declarations, {
                module = moduleName,
                startOffset = tokenOffset(offsets, tokens[startPosition]),
                endOffset = tokenOffset(offsets, tokens[closePosition]),
            })
            position = closePosition + 1
        else
            position = position + 1
        end
    end
    return declarations
end

local function stripDeclarations(source, declarations)
    local chunks = {}
    local position = 1
    for _, declaration in ipairs(declarations) do
        table.insert(chunks, source:sub(position, declaration.startOffset - 1))
        table.insert(chunks, "-- bundled import: " .. declaration.module .. "\n")
        position = declaration.endOffset + 1
    end
    table.insert(chunks, source:sub(position))
    return table.concat(chunks)
end

function LuaBundler.bundle(source, options)
    assert(type(source) == "string", "LuaBundler.bundle expects source text")
    options = options or {}
    local rootDirectory = options.rootPath and pathDirectory(options.rootPath)
    local visited = {}
    local visiting = {}
    local ordered = {}

    local function visit(moduleName)
        if STANDARD_MODULES[moduleName] then
            return
        end
        if visited[moduleName] then
            return
        end
        if visiting[moduleName] then
            error("LuaBundler Error: cyclic local module dependency involving '" .. moduleName .. "'")
        end
        if not rootDirectory then
            error("LuaBundler Error: local module '" .. moduleName .. "' requires a rootPath")
        end

        visiting[moduleName] = true
        local path = resolveModule(moduleName, rootDirectory)
        local moduleSource = readFile(path)
        local declarations = requireDeclarations(moduleSource)
        for _, declaration in ipairs(declarations) do
            visit(declaration.module)
        end
        visited[moduleName] = true
        visiting[moduleName] = nil
        table.insert(ordered, {
            name = moduleName,
            path = path,
            source = stripDeclarations(moduleSource, declarations),
        })
    end

    local declarations = requireDeclarations(source)
    for _, declaration in ipairs(declarations) do
        visit(declaration.module)
    end

    local chunks = {}
    for _, module in ipairs(ordered) do
        table.insert(chunks, "-- BEGIN BUNDLED MODULE: " .. module.name .. "\n")
        table.insert(chunks, module.source)
        table.insert(chunks, "\n-- END BUNDLED MODULE: " .. module.name .. "\n\n")
    end
    table.insert(chunks, stripDeclarations(source, declarations))

    return {
        source = table.concat(chunks),
        modules = ordered,
    }
end

function LuaBundler.bundleFile(path)
    return LuaBundler.bundle(readFile(path), { rootPath = path })
end

return LuaBundler
