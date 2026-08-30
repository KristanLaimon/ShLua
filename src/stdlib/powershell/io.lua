local M = { name = "io" }

M.functions = {
    ["io.flush"] = "__shlua_io_flush",
    ["io.open"] = "__shlua_io_open",
    ["io.read"] = "__shlua_io_read",
    ["io.write"] = "__shlua_io_write",
}

M.unsupported = {
    ["io.input"] = "default-file switching is not implemented",
    ["io.lines"] = "iterator and file-handle support is not implemented",
    ["io.output"] = "default-file switching is not implemented",
    ["io.popen"] = "process file handles are not implemented",
    ["io.tmpfile"] = "file handles are not implemented",
    ["io.type"] = "file handles are not implemented",
}

M.source = [=[function __shlua_io_write {
    param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Values)
    foreach ($Value in $Values) { [Console]::Write([string] $Value) }
}
function __shlua_io_flush { [Console]::Out.Flush() }
function __shlua_io_open {
    param($Path, $Mode)
    if ($Mode -ne 'w') { return $null }
    try {
        [IO.File]::WriteAllText([string] $Path, '')
        return $Path
    } catch {
        return $null
    }
}
function __shlua_io_file_write {
    param($Path, $Value)
    [IO.File]::AppendAllText([string] $Path, [string] $Value)
}
function __shlua_io_file_close { }
function __shlua_io_read { [Console]::ReadLine() }]=]

return M
