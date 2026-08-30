local CLI = require("cli")
local Lexer = require("lexer")
local LuaBundler = require("luabundler")
local Parser = require("parser")
local TranspilerInterface = require("ITranspiler")

---@class ShLua
---@field VERSION string Compiler version.
local ShLua = { VERSION = "0.1.0-alpha" }

local TARGETS = {
    bash = require("bash_transpiler"),
    ps1 = require("ps1_transpiler"),
}
local TARGET_ORDER = { "bash", "ps1" }

for name, module in pairs(TARGETS) do
    TranspilerInterface.validate(module, name)
end

---Prints an AST-like table recursively for the CLI dump mode.
---@param value table Table to display.
---@param level? integer Current indentation level.
---@return nil
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

---Bundles standard imports and project-local modules before parsing.
---@param source string Root Lua source.
---@param options? ShLuaBundleOptions Local-module resolution options.
---@return ShLuaBundle bundle Require-free bundle.
function ShLua.bundle(source, options)
    return LuaBundler.bundle(source, options)
end

---Parses source after resolving supported `require` declarations.
---@param source string Lua source to parse.
---@param options? ShLuaBundleOptions Local-module resolution options.
---@return ShLuaProgram program Parsed program AST.
function ShLua.parse(source, options)
    assert(type(source) == "string", "ShLua.parse expects source text")
    local bundled = ShLua.bundle(source, options)
    return Parser.new(Lexer.new(bundled.source):tokenize()):parse()
end

---Transpiles in-memory Lua source to one target or both targets.
---@param source string Lua source text.
---@param target? "bash"|"ps1"|"all" Output target, defaulting to `all`.
---@param options? ShLuaBundleOptions Local-module resolution options.
---@return string|table code Generated target code.
---@example
---local bash = ShLua.transpile("print('hello')", "bash")
function ShLua.transpile(source, target, options)
    target = target or "all"
    if target ~= "all" and not TARGETS[target] then
        error("ShLua Error: target must be 'bash', 'ps1', or 'all'")
    end
    local ast = ShLua.parse(source, options)
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

---Reads, bundles, and transpiles an entry Lua file.
---@param path string Entry file path used as the module-resolution root.
---@param target? "bash"|"ps1"|"all" Output target.
---@return string|table code Generated target code.
function ShLua.transpileFile(path, target)
    assert(type(path) == "string", "ShLua.transpileFile expects an input path")
    return ShLua.transpile(CLI.readFile(path), target, { rootPath = path })
end

ShLua.compile = ShLua.transpile

---Adds or replaces an output extension for a generated target file.
---@param basePath string Requested output base path.
---@param extension string Target extension including its dot.
---@return string path Final output path.
local function outputPath(basePath, extension)
    if basePath:sub(-#extension) == extension then
        return basePath
    end
    return basePath:gsub("%.[^./\\]+$", "") .. extension
end

---Runs the CLI compilation workflow and returns a process-style exit code.
---@param rawArgs? string[] CLI arguments, defaulting to the global `arg` table.
---@return integer exitCode Zero for success, one for a recoverable compiler error.
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
        local bundled = ShLua.bundle(source, { rootPath = opts.input })
        if opts.verbose then
            print("[shlua] bundled " .. #bundled.modules .. " local module(s) from " .. opts.input)
        end
        local ast = Parser.new(Lexer.new(bundled.source):tokenize()):parse()
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
