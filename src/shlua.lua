local CLI = require("cli")
local Lexer = require("lexer")
local Parser = require("parser")
local TranspilerInterface = require("ITranspiler")

local ShLua = { VERSION = "0.1.0-alpha" }

local TARGETS = {
    bash = require("bash_transpiler"),
    ps1 = require("ps1_transpiler"),
}
local TARGET_ORDER = { "bash", "ps1" }

for name, module in pairs(TARGETS) do
    TranspilerInterface.validate(module, name)
end

local function dumpValue(value, level)
    level = level or 0
    local keys = {}
    for key in pairs(value) do
        table.insert(keys, key)
    end
    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)
    for _, key in ipairs(keys) do
        local item = value[key]
        if type(item) == "table" then
            print(string.rep("  ", level) .. tostring(key) .. ":")
            dumpValue(item, level + 1)
        else
            print(string.rep("  ", level) .. tostring(key) .. ": " .. tostring(item))
        end
    end
end

function ShLua.parse(source)
    assert(type(source) == "string", "ShLua.parse expects source text")
    return Parser.new(Lexer.new(source):tokenize()):parse()
end

function ShLua.transpile(source, target)
    target = target or "all"
    if target ~= "all" and not TARGETS[target] then
        error("ShLua Error: target must be 'bash', 'ps1', or 'all'")
    end
    local ast = ShLua.parse(source)
    if target == "all" then
        local results = {}
        for _, name in ipairs(TARGET_ORDER) do
            local module = TARGETS[name]
            results[name] = module.Serializer.serialize(module.new():translate(ast))
        end
        return results
    end
    local module = TARGETS[target]
    return module.Serializer.serialize(module.new():translate(ast))
end

ShLua.compile = ShLua.transpile

local function outputPath(basePath, extension)
    if basePath:sub(-#extension) == extension then
        return basePath
    end
    return basePath:gsub("%.[^./\\]+$", "") .. extension
end

function ShLua.main(rawArgs)
    local parsed, opts = pcall(CLI.parse, rawArgs or {})
    if not parsed then
        io.stderr:write(tostring(opts) .. "\n")
        return 1
    end
    if opts.help then
        CLI.showHelp()
        return 0
    end

    local success, failure = pcall(function()
        local source = CLI.readFile(opts.input)
        if opts.verbose then
            print("[shlua] parsing " .. opts.input)
        end
        local ast = ShLua.parse(source)
        if opts.dumpAst then
            print("=== LUA AST DUMP ===")
            dumpValue(ast)
            return
        end

        local names = opts.target == "all" and TARGET_ORDER or { opts.target }
        for _, name in ipairs(names) do
            local module = TARGETS[name]
            local code = module.Serializer.serialize(module.new():translate(ast))
            if opts.output then
                local path = outputPath(opts.output, module.extension)
                CLI.writeFile(path, code)
                if opts.verbose then
                    print("[shlua] wrote " .. path)
                end
            else
                print("\n=================== Output: " .. name:upper() .. " ===================")
                io.write(code)
            end
        end
    end)
    if not success then
        io.stderr:write(tostring(failure) .. "\n")
        return 1
    end
    return 0
end

return ShLua
