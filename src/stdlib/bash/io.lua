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

M.source = [[__luash_io_write() {
    printf '%s' "$@"
}

__luash_io_flush() {
    return 0
}

__luash_io_read() {
    local __luash_value
    IFS= read -r __luash_value || return 0
    printf '%s\n' "$__luash_value"
}]]

return M
