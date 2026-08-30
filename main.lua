local source = debug.getinfo(1, "S").source
local scriptPath = source:sub(1, 1) == "@" and source:sub(2) or "main.lua"
local scriptDir = scriptPath:match("^(.*)[/\\]") or "."
package.path = scriptDir .. "/src/?.lua;" .. scriptDir .. "/src/?/init.lua;" .. package.path

local ShLua = require("shlua")
local exitCode = ShLua.main(arg)
if exitCode ~= 0 then
    os.exit(exitCode)
end
