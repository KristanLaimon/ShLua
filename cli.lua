-- ============================================================================
-- Generic CLI Argument Parser & Option Handler
-- File: cli.lua
-- ============================================================================

local CLI = {}
local NAME = "luatranspile"
local VERSION = "1.0.0"

function CLI.showHelp()
	print(string.format(
		[[
%s v%s - Transpile Lua code to Bash, PowerShell, or both.

USAGE:
    lua main.lua [OPTIONS] -i <input.lua> [-o <output_prefix>]

OPTIONS:
    -i, --input <file>     Path to input Lua script (Required).
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

function CLI.readFile(filepath)
	local file, err = io.open(filepath, "r")
	if not file then
		error("CLI Error: Cannot open input file '" .. tostring(filepath) .. "': " .. tostring(err))
	end
	local content = file:read("*a")
	file:close()
	return content
end

function CLI.writeFile(filepath, content)
	local file, err = io.open(filepath, "w")
	if not file then
		error("CLI Error: Cannot write output file '" .. tostring(filepath) .. "': " .. tostring(err))
	end
	file:write(content)
	file:close()
end

function CLI.parse(rawArgs)
	local opts = {
		input = nil,
		output = nil,
		target = "all", -- Default is set to transpile to both languages
		dumpAst = false,
		verbose = false,
	}

	local i = 1
	while i <= #rawArgs do
		local a = rawArgs[i]
		if a == "-h" or a == "--help" then
			CLI.showHelp()
			os.exit(0)
		elseif a == "-v" or a == "--verbose" then
			opts.verbose = true
		elseif a == "-a" or a == "--dump-ast" then
			opts.dumpAst = true
		elseif a == "-i" or a == "--input" then
			i = i + 1
			opts.input = rawArgs[i]
		elseif a == "-o" or a == "--output" then
			i = i + 1
			opts.output = rawArgs[i]
		elseif a == "-t" or a == "--target" then
			i = i + 1
			opts.target = rawArgs[i]:lower()
		else
			error(string.format("CLI Error: Unknown option '%s'", a))
		end
		i = i + 1
	end

	if not opts.input then
		error("CLI Error: Input file missing. Specify one using '-i <file>'.")
	end

	return opts
end

return CLI
