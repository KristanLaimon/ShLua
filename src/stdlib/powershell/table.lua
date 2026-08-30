local M = { name = "table" }

M.functions = {}

M.unsupported = {
    ["table.concat"] = "table constructors and indexing are not yet implemented",
    ["table.insert"] = "mutable table values are not yet implemented",
    ["table.maxn"] = "table constructors and indexing are not yet implemented",
    ["table.remove"] = "mutable table values are not yet implemented",
    ["table.sort"] = "mutable table values are not yet implemented",
}

M.source = ""

return M
