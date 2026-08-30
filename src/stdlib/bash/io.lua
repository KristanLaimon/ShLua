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

M.source = [[__shlua_io_write() {
    printf '%s' "$@"
}

__shlua_io_flush() {
    return 0
}

__shlua_io_open() {
    local __shlua_path="$1"
    local __shlua_mode="$2"
    if [ "$__shlua_mode" != 'w' ]; then
        return 1
    fi
    : > "$__shlua_path" || return 1
    printf '%s' "$__shlua_path"
}

__shlua_io_file_write() {
    printf '%s' "$2" >> "$1"
}

__shlua_io_file_close() {
    return 0
}

__shlua_io_read() {
    local __shlua_value
    IFS= read -r __shlua_value || return 0
    printf '%s\n' "$__shlua_value"
}]]

return M
