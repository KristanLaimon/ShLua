local M = { name = "base" }

M.functions = {
    ["tonumber"] = "__shlua_tonumber",
    ["tostring"] = "__shlua_tostring",
    ["type"] = "__shlua_type",
}

M.unsupported = {
    ["assert"] = "multiple return values are not implemented",
    ["collectgarbage"] = "has no target-shell equivalent",
    ["dofile"] = "loading Lua source at runtime is not supported",
    ["error"] = "Lua stack unwinding is not implemented",
    ["getfenv"] = "Lua environments are not implemented",
    ["getmetatable"] = "metatables are not implemented",
    ["load"] = "loading Lua source at runtime is not supported",
    ["loadfile"] = "loading Lua source at runtime is not supported",
    ["loadstring"] = "loading Lua source at runtime is not supported",
    ["module"] = "Lua modules are not implemented in generated scripts",
    ["newproxy"] = "userdata and metatables are not implemented",
    ["next"] = "general table iteration is not implemented",
    ["pcall"] = "Lua protected calls are not implemented",
    ["rawequal"] = "metatables and raw access are not implemented",
    ["rawget"] = "metatables and raw access are not implemented",
    ["rawset"] = "metatables and raw access are not implemented",
    ["require"] = "generated scripts are self-contained",
    ["select"] = "varargs are not implemented",
    ["setfenv"] = "Lua environments are not implemented",
    ["setmetatable"] = "metatables are not implemented",
    ["unpack"] = "multiple return values are not implemented",
    ["xpcall"] = "Lua protected calls are not implemented",
}

M.source = [=[__shlua_tostring() {
    if [ $# -eq 0 ]; then
        printf 'nil\n'
    else
        printf '%s\n' "$1"
    fi
}

__shlua_tonumber() {
    local __shlua_value="$1"
    local __shlua_base="${2:-10}"
    if [ "$__shlua_base" -ne 10 ]; then
        LC_ALL=C awk -v value="$__shlua_value" -v base="$__shlua_base" '
            BEGIN {
                digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                value = toupper(value)
                result = 0
                for (i = 1; i <= length(value); i++) {
                    digit = index(digits, substr(value, i, 1)) - 1
                    if (digit < 0 || digit >= base) exit
                    result = result * base + digit
                }
                print result
            }
        ' </dev/null
        return 0
    fi
    case "$__shlua_value" in
        ''|*[!0-9eE+.-]*) return 0 ;;
        *) printf '%s\n' "$__shlua_value" ;;
    esac
}

__shlua_type() {
    local __shlua_value="$1"
    if [ $# -eq 0 ]; then
        printf 'nil\n'
    elif [ "$__shlua_value" = 'true' ] || [ "$__shlua_value" = 'false' ]; then
        printf 'boolean\n'
    elif [[ "$__shlua_value" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        printf 'number\n'
    elif [ -d "$__shlua_value" ] && [ -f "$__shlua_value/count" ]; then
        printf 'table\n'
    elif [[ "$__shlua_value" = __shlua_closure_* ]] || declare -F "$__shlua_value" >/dev/null 2>&1; then
        printf 'function\n'
    else
        printf 'string\n'
    fi
}]=]

return M
