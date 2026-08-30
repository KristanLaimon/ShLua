---@meta

---Lua tokens emitted by the ShLua lexer.
---@alias ShLuaTokenType
---| "KEYWORD"
---| "IDENTIFIER"
---| "NUMBER"
---| "STRING"
---| "OPERATOR"
---| "COMMENT"
---| "EOF"

---@class ShLuaToken
---@field type ShLuaTokenType Token category.
---@field value string Raw or decoded token value.
---@field line integer One-based source line.
---@field column integer One-based source column.

---@class ShLuaProgram
---@field type "Program"
---@field body ShLuaStatement[]
---@field scopeResolved? boolean

---@alias ShLuaExpression table
---@alias ShLuaStatement table

---@class ShLuaBundleOptions
---@field rootPath? string Input file used to resolve local modules.

---@class ShLuaBundledModule
---@field name string Dotted module name.
---@field path string Resolved module path.
---@field source string Require-free module source.

---@class ShLuaBundle
---@field source string Flattened require-free Lua source.
---@field modules ShLuaBundledModule[] Modules in dependency order.

---@class ShLuaCliOptions
---@field input? string
---@field output? string
---@field target "bash"|"ps1"|"all"
---@field dumpAst boolean
---@field verbose boolean
---@field help boolean

---@class ShLuaTargetAst
---@field type string
---@field program ShLuaProgram
---@field runtime table

---@class ShLuaTranspilerModule
---@field name string
---@field extension string
---@field new fun(): table
---@field translate fun(self: table, ast: ShLuaProgram): ShLuaTargetAst
---@field Serializer { serialize: fun(ast: ShLuaTargetAst): string }
