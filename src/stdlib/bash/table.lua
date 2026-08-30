local M = { name = "table" }

M.functions = {}

M.unsupported = {
    ["table.concat"] = "table values are not yet representable as scalar Bash call arguments",
    ["table.insert"] = "mutable table values are not yet implemented",
    ["table.maxn"] = "table values are not yet implemented",
    ["table.remove"] = "mutable table values are not yet implemented",
    ["table.sort"] = "mutable table values are not yet implemented",
}

M.source = ""

return M
