package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

require("stdlib_conformance").run("ps1", "09_powershell_stdlib", "3.14159265358979")

lust.report()
