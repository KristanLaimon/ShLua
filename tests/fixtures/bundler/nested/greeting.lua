local string = require("string")
local decoration = require("nested.decoration")

function greet(name)
    return string.upper(decorate(name))
end
