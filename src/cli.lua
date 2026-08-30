-- ============================================================================
-- Generic CLI Argument Parser & Option Handler
-- File: cli.lua
-- ============================================================================

---@class CLI
local CLI = {}
local NAME = "ShLua"
local VERSION = "0.9.0-beta"

---Prints command-line usage and supported options.
---@return nil
function CLI.showHelp()
    print(string.format(
        [[
%s v%s - Transpile Lua code to Bash, PowerShell, or both.

USAGE:
			lua main.lua <input.lua> [OPTIONS]
			lua main.lua -i <input.lua> [OPTIONS]

OPTIONS:
    -i, --input <file>     Path to input Lua script.
    -o, --output <file>    Base path for output files (Optional).
                           If target is 'all', target extensions (.sh/.ps1) are appended.
    -t, --target <target>  Target language: 'bash', 'ps1', or 'all' (Default: 'all').
    -a, --dump-ast         Print source Lua AST to stdout and exit.
    -v, --verbose          Print execution pipeline trace details.
    -h, --help             Show this help menu and exit.
]],
        NAME,
        VERSION
    ))
end

---Reads a complete source file.
---@param filepath string Path to read.
---@return string content File contents.
function CLI.readFile(filepath)
    local file, err = io.open(filepath, "r")
    if not file then
        error("CLI Error: Cannot open input file '" .. tostring(filepath) .. "': " .. tostring(err))
    end
    local content = file:read("*a")
    file:close()
    return content
end

---Writes generated output to a file.
---@param filepath string Destination path.
---@param content string Text to write.
---@return nil
function CLI.writeFile(filepath, content)
    local file, err = io.open(filepath, "w")
    if not file then
        error("CLI Error: Cannot write output file '" .. tostring(filepath) .. "': " .. tostring(err))
    end
    file:write(content)
    file:close()
end

---Parses ShLua command-line arguments into compiler options.
---@param rawArgs string[] Arguments excluding the executable name.
---@return ShLuaCliOptions options Parsed CLI options.
---@example
---local options = CLI.parse({ "-i", "main.lua", "-t", "bash" })
function CLI.parse(rawArgs)
    local opts = {
        input = nil,
        output = nil,
        target = "all", -- Default is set to transpile to both languages
        dumpAst = false,
        verbose = false,
        help = false,
    }

    local i = 1
    while i <= #rawArgs do
        local a = rawArgs[i]
        if a == "-h" or a == "--help" then
            opts.help = true
        elseif a == "-v" or a == "--verbose" then
            opts.verbose = true
        elseif a == "-a" or a == "--dump-ast" then
            opts.dumpAst = true
        elseif a == "-i" or a == "--input" then
            i = i + 1
            if not rawArgs[i] then
                error("CLI Error: --input requires a file path")
            elseif opts.input then
                error("CLI Error: input file was specified more than once")
            end
            opts.input = rawArgs[i]
        elseif a == "-o" or a == "--output" then
            i = i + 1
            if not rawArgs[i] then
                error("CLI Error: --output requires a file path")
            end
            opts.output = rawArgs[i]
        elseif a == "-t" or a == "--target" then
            i = i + 1
            if not rawArgs[i] then
                error("CLI Error: --target requires bash, ps1, or all")
            end
            opts.target = rawArgs[i]:lower()
        elseif a:sub(1, 1) == "-" then
            error(string.format("CLI Error: Unknown option '%s'", a))
        elseif opts.input then
            error(string.format("CLI Error: Unexpected extra input file '%s'", a))
        else
            opts.input = a
        end
        i = i + 1
    end

    if not opts.help and not opts.input then
        error("CLI Error: Input file missing. Usage: lua shlua.lua <input.lua> [OPTIONS]")
    end
    if opts.target ~= "bash" and opts.target ~= "ps1" and opts.target ~= "all" then
        error("CLI Error: target must be 'bash', 'ps1', or 'all'")
    end

    return opts
end

return CLI
