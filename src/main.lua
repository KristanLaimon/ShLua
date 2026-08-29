-- ============================================================================
-- Main Entry Point (Application Wiring & Multi-Target Orchestration)
-- File: main.lua
-- ============================================================================

local CLI = require("cli")
local Lexer = require("lexer")
local Parser = require("parser")
local TranspilerInterface = require("transpiler_interface")

-- 1. Transpiler Registry (Maps targets to their implementation modules)
local REGISTERED_TRANSPILERS = {
	bash = require("bash_transpiler"),
	ps1 = require("ps1_transpiler"),
}

-- Validate all registered transpilers against the interface contract on boot
for key, module in pairs(REGISTERED_TRANSPILERS) do
	TranspilerInterface.validate(module, key)
end

local function main()
	-- 2. Parse Options
	local success, opts = pcall(CLI.parse, arg)
	if not success then
		print(opts)
		os.exit(1)
	end

	-- 3. Determine Selected Targets
	local activeTranspilers = {}
	if opts.target == "all" then
		for _, tModule in pairs(REGISTERED_TRANSPILERS) do
			table.insert(activeTranspilers, tModule)
		end
	elseif REGISTERED_TRANSPILERS[opts.target] then
		table.insert(activeTranspilers, REGISTERED_TRANSPILERS[opts.target])
	else
		print(string.format("Error: Invalid target '%s'. Valid targets: 'bash', 'ps1', 'all'", opts.target))
		os.exit(1)
	end

	-- 4. Frontend Compilation Pipeline (Shared across all targets)
	if opts.verbose then
		print("[+] Reading source file: " .. opts.input)
	end
	local sourceCode = CLI.readFile(opts.input)

	if opts.verbose then
		print("[+] Step 1: Tokenizing source code...")
	end
	local tokens = Lexer.new(sourceCode):tokenize()

	if opts.verbose then
		print("[+] Step 2: Parsing tokens into Lua AST...")
	end
	local luaAST = Parser.new(tokens):parse()

	if opts.dumpAst then
		print("=== LUA AST DUMP ===")
		-- Simple dump utility
		local function dump(tbl, indent)
			indent = indent or 0
			for k, v in pairs(tbl) do
				if type(v) == "table" then
					print(string.rep("  ", indent) .. tostring(k) .. ":")
					dump(v, indent + 1)
				else
					print(string.rep("  ", indent) .. tostring(k) .. ": " .. tostring(v))
				end
			end
		end
		dump(luaAST)
		os.exit(0)
	end

	-- 5. Execution Pipeline via Polymorphic Interface
	for _, TranspilerModule in ipairs(activeTranspilers) do
		if opts.verbose then
			print(string.format("[+] Step 3: Transpiling to target AST [%s]...", TranspilerModule.name))
		end

		-- Call uniform interface methods
		local instance = TranspilerModule.new()
		local targetAST = instance:translate(luaAST)

		if opts.verbose then
			print(string.format("[+] Step 4: Serializing code for [%s]...", TranspilerModule.name))
		end
		local outputCode = TranspilerModule.Serializer.serialize(targetAST)

		-- 6. Output Handling
		if opts.output then
			local destPath = opts.output
			if opts.target == "all" or not destPath:match("%" .. TranspilerModule.extension .. "$") then
				destPath = destPath:gsub("%.%w+$", "") .. TranspilerModule.extension
			end

			if opts.verbose then
				print(string.format("[+] Writing output to: %s", destPath))
			end
			CLI.writeFile(destPath, outputCode)
		else
			print(string.format("\n=================== Output: %s ===================", TranspilerModule.name:upper()))
			io.write(outputCode .. "\n")
		end
	end

	if opts.verbose then
		print("[+] Done!")
	end
end

main()
