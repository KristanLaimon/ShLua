local M = { name = "io" }

M.functions = {
    ["io.flush"] = "__shlua_io_flush",
    ["io.read"] = "__shlua_io_read",
    ["io.write"] = "__shlua_io_write",
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

M.source = [[__shlua_io_write() {
    printf '%s' "$@"
}

__shlua_io_flush() {
    return 0
}

__shlua_io_read() {
    local __shlua_value
    IFS= read -r __shlua_value || return 0
    printf '%s\n' "$__shlua_value"
}]]

return M
