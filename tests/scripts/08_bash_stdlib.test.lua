package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

require("stdlib_conformance").run("bash", "08_bash_stdlib", "3.14159265358979323846")

lust.report()
