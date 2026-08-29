-- ============================================================================
-- Interface Contract Specification: Transpiler Module
-- File: transpiler_interface.lua
-- ============================================================================
--
-- Any new target language transpiler MUST implement this interface contract.
--
-- @class TranspilerInterface
-- @field name string The lower-case identifier for the target (e.g., "bash", "ps1")
-- @field extension string Target file extension including dot (e.g., ".sh", ".ps1")
--
-- Interface Methods:
--
-- 1. Constructor:
--    @function TargetTranspiler.new()
--    @return TargetTranspiler Instance of the transpiler state machine.
--
-- 2. AST Transformer:
--    @method transpiler:translate(luaAST)
--    @param luaAST table Root node of the Lua Abstract Syntax Tree.
--    @return TargetAST table Root node of the target language AST.
--
-- 3. Serializer Sub-module:
--    @field TargetTranspiler.Serializer table Sub-module handling code generation.
--    @function TargetTranspiler.Serializer.serialize(targetAST)
--    @param targetAST table Target AST returned by translate()
--    @return string Serialized executable source code text.
-- ============================================================================

local TranspilerInterface = {}

--- Optional runtime validator to ensure a module satisfies the contract
function TranspilerInterface.validate(module, moduleName)
    assert(type(module) == "table", moduleName .. " must be a table")
    assert(type(module.name) == "string", moduleName .. " missing '.name' string")
    assert(type(module.extension) == "string", moduleName .. " missing '.extension' string")
    assert(type(module.new) == "function", moduleName .. " missing '.new()' constructor")
    assert(type(module.Serializer) == "table", moduleName .. " missing '.Serializer' table")
    assert(type(module.Serializer.serialize) == "function", moduleName .. " missing '.Serializer.serialize()' method")
end

return TranspilerInterface
