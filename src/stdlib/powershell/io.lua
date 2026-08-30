local M = { name = "io" }

M.functions = {
    ["io.flush"] = "__luash_io_flush",
    ["io.read"] = "__luash_io_read",
    ["io.write"] = "__luash_io_write",
}

M.unsupported = {
    ["io.close"] = "file handles are not implemented",
    ["io.input"] = "default-file switching is not implemented",
    ["io.lines"] = "iterator and file-handle support is not implemented",
    ["io.open"] = "file handles are not implemented",
    ["io.output"] = "default-file switching is not implemented",
    ["io.popen"] = "process file handles are not implemented",
    ["io.tmpfile"] = "file handles are not implemented",
    ["io.type"] = "file handles are not implemented",
}

M.source = [=[function __luash_io_write {
    param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Values)
    foreach ($Value in $Values) { [Console]::Write([string] $Value) }
}
function __luash_io_flush { [Console]::Out.Flush() }
function __luash_io_read { [Console]::ReadLine() }]=]

return M
