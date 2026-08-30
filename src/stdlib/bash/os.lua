local M = { name = "os" }

M.functions = {
    ["os.clock"] = "__shlua_os_clock",
    ["os.date"] = "__shlua_os_date",
    ["os.difftime"] = "__shlua_os_difftime",
    ["os.execute"] = "__shlua_os_execute",
    ["os.exit"] = "__shlua_os_exit",
    ["os.getenv"] = "__shlua_os_getenv",
    ["os.remove"] = "__shlua_os_remove",
    ["os.rename"] = "__shlua_os_rename",
    ["os.time"] = "__shlua_os_time",
    ["os.tmpname"] = "__shlua_os_tmpname",
}

M.unsupported = {
    ["os.setlocale"] = "locale mutation is not portable across target shells",
}

M.prefix = [[__shlua_os_clock_started="${SECONDS:-0}"]]
M.prefixHelpers = { __shlua_os_clock = true }

M.source = [[__shlua_os_clock_started="${SECONDS:-0}"

__shlua_os_clock() {
    LC_ALL=C awk -v now="${SECONDS:-0}" -v started="$__shlua_os_clock_started" '
        BEGIN { printf "%.2f\n", now - started }
    ' </dev/null
}

__shlua_os_date() {
    local __shlua_format="${1:-%c}"
    local __shlua_time="$2"
    if [ -n "$__shlua_time" ]; then
        date -d "@$__shlua_time" "+$__shlua_format"
    else
        date "+$__shlua_format"
    fi
}

__shlua_os_difftime() {
    LC_ALL=C awk -v first="$1" -v second="$2" 'BEGIN { print first - second }' </dev/null
}

__shlua_os_execute() {
    if [ $# -eq 0 ]; then
        return 0
    fi
    eval "$1"
}

__shlua_os_exit() { exit "${1:-0}"; }
__shlua_os_getenv() { local __shlua_name="$1"; printf '%s\n' "${!__shlua_name}"; }
__shlua_os_remove() { rm -- "$1"; }
__shlua_os_rename() { mv -- "$1" "$2"; }
__shlua_os_time() { date '+%s'; }
__shlua_os_tmpname() { mktemp "${TMPDIR:-/tmp}/shlua.XXXXXX"; }]]

return M
