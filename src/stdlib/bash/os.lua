local M = { name = "os" }

M.functions = {
    ["os.clock"] = "__luash_os_clock",
    ["os.date"] = "__luash_os_date",
    ["os.difftime"] = "__luash_os_difftime",
    ["os.execute"] = "__luash_os_execute",
    ["os.exit"] = "__luash_os_exit",
    ["os.getenv"] = "__luash_os_getenv",
    ["os.remove"] = "__luash_os_remove",
    ["os.rename"] = "__luash_os_rename",
    ["os.time"] = "__luash_os_time",
    ["os.tmpname"] = "__luash_os_tmpname",
}

M.unsupported = {
    ["os.setlocale"] = "locale mutation is not portable across target shells",
}

M.prefix = [[__luash_os_clock_started="${SECONDS:-0}"]]
M.prefixHelpers = { __luash_os_clock = true }

M.source = [[__luash_os_clock_started="${SECONDS:-0}"

__luash_os_clock() {
    LC_ALL=C awk -v now="${SECONDS:-0}" -v started="$__luash_os_clock_started" '
        BEGIN { printf "%.2f\n", now - started }
    ' </dev/null
}

__luash_os_date() {
    local __luash_format="${1:-%c}"
    local __luash_time="$2"
    if [ -n "$__luash_time" ]; then
        date -d "@$__luash_time" "+$__luash_format"
    else
        date "+$__luash_format"
    fi
}

__luash_os_difftime() {
    LC_ALL=C awk -v first="$1" -v second="$2" 'BEGIN { print first - second }' </dev/null
}

__luash_os_execute() {
    if [ $# -eq 0 ]; then
        return 0
    fi
    eval "$1"
}

__luash_os_exit() { exit "${1:-0}"; }
__luash_os_getenv() { local __luash_name="$1"; printf '%s\n' "${!__luash_name}"; }
__luash_os_remove() { rm -- "$1"; }
__luash_os_rename() { mv -- "$1" "$2"; }
__luash_os_time() { date '+%s'; }
__luash_os_tmpname() { mktemp "${TMPDIR:-/tmp}/luash.XXXXXX"; }]]

return M
