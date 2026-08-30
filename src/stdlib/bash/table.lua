local M = { name = "table" }

M.functions = {
    ["table.concat"] = "__shlua_table_concat",
    ["table.insert"] = "__shlua_table_insert",
    ["table.maxn"] = "__shlua_table_maxn",
    ["table.remove"] = "__shlua_table_remove",
    ["table.sort"] = "__shlua_table_sort",
}

M.unsupported = {
    pairs = "pairs is supported only as the iterator of a generic for loop",
    ipairs = "ipairs is supported only as the iterator of a generic for loop",
}

M.prefix = [=[__shlua_table_root="$(mktemp -d "${TMPDIR:-/tmp}/shlua-table.XXXXXX")" || exit 1
__shlua_table_cleanup() {
    rm -rf -- "$__shlua_table_root"
}
trap '__shlua_table_cleanup' EXIT]=]

M.callHelpers = {
    ipairs = { "__shlua_table_contains", "__shlua_table_get" },
    pairs = { "__shlua_table_entry_exists", "__shlua_table_entry_key", "__shlua_table_entry_value" },
}

M.dependencies = {
    __shlua_table_find = { "__shlua_table_infer_key_type", "__shlua_table_normalize_number" },
    __shlua_table_set = { "__shlua_table_infer_key_type", "__shlua_table_normalize_number", "__shlua_table_find" },
    __shlua_table_new = { "__shlua_table_set" },
    __shlua_table_contains = { "__shlua_table_find" },
    __shlua_table_get = { "__shlua_table_find" },
    __shlua_table_length = { "__shlua_table_contains" },
    __shlua_length = { "__shlua_table_length" },
    __shlua_table_concat = { "__shlua_table_length", "__shlua_table_contains", "__shlua_table_get" },
    __shlua_table_insert = { "__shlua_table_length", "__shlua_table_set", "__shlua_table_get" },
    __shlua_table_remove = { "__shlua_table_length", "__shlua_table_get", "__shlua_table_set" },
    __shlua_table_sort = {
        "__shlua_table_length",
        "__shlua_table_get",
        "__shlua_table_truthy",
        "__shlua_table_less",
        "__shlua_table_set",
    },
}

M.source = [=[__shlua_table_root="$(mktemp -d "${TMPDIR:-/tmp}/shlua-table.XXXXXX")" || exit 1
__shlua_table_cleanup() {
    rm -rf -- "$__shlua_table_root"
}
trap '__shlua_table_cleanup' EXIT

__shlua_table_infer_key_type() {
    if [[ "$1" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        printf 'n'
    else
        printf 's'
    fi
}

__shlua_table_normalize_number() {
    local __shlua_value="$1"
    local __shlua_sign=''
    if [[ "$__shlua_value" =~ ^[-+]?[0-9]+$ ]]; then
        case "$__shlua_value" in
            -*) __shlua_sign='-'; __shlua_value="${__shlua_value#-}" ;;
            +*) __shlua_value="${__shlua_value#+}" ;;
        esac
        while [ "${#__shlua_value}" -gt 1 ] && [ "${__shlua_value#0}" != "$__shlua_value" ]; do
            __shlua_value="${__shlua_value#0}"
        done
        if [ "$__shlua_value" = '0' ]; then
            __shlua_sign=''
        fi
        printf '%s%s' "$__shlua_sign" "$__shlua_value"
    else
        LC_ALL=C awk -v value="$__shlua_value" 'BEGIN { printf "%.15g", value + 0 }' </dev/null
    fi
}

__shlua_table_find() {
    local __shlua_table="$1"
    local __shlua_type="$2"
    local __shlua_key="$3"
    if [ -z "$__shlua_type" ]; then
        __shlua_type="$(__shlua_table_infer_key_type "$__shlua_key")"
    fi
    if [ "$__shlua_type" = 'z' ]; then
        return 0
    elif [ "$__shlua_type" = 'n' ]; then
        __shlua_key="$(__shlua_table_normalize_number "$__shlua_key")"
    fi

    local __shlua_count
    local __shlua_index=1
    __shlua_count="$(<"$__shlua_table/count")"
    while [ "$__shlua_index" -le "$__shlua_count" ]; do
        if [ -f "$__shlua_table/$__shlua_index/type" ] \
            && [ "$(<"$__shlua_table/$__shlua_index/type")" = "$__shlua_type" ] \
            && [ "$(<"$__shlua_table/$__shlua_index/key")" = "$__shlua_key" ]; then
            printf '%s' "$__shlua_index"
            return 0
        fi
        __shlua_index=$((__shlua_index + 1))
    done
}

__shlua_table_set() {
    local __shlua_table="$1"
    local __shlua_type="$2"
    local __shlua_key="$3"
    local __shlua_value="$4"
    local __shlua_present="${5:-1}"
    if [ "$__shlua_type" = 'z' ]; then
        printf 'ShLua table error: table index is nil\n' >&2
        return 1
    fi
    if [ -z "$__shlua_type" ]; then
        __shlua_type="$(__shlua_table_infer_key_type "$__shlua_key")"
    fi
    if [ "$__shlua_type" = 'n' ]; then
        __shlua_key="$(__shlua_table_normalize_number "$__shlua_key")"
    fi

    local __shlua_index
    __shlua_index="$(__shlua_table_find "$__shlua_table" "$__shlua_type" "$__shlua_key")"
    if [ "$__shlua_present" = '0' ]; then
        if [ -n "$__shlua_index" ]; then
            rm -f -- "$__shlua_table/$__shlua_index/type" "$__shlua_table/$__shlua_index/key" \
                "$__shlua_table/$__shlua_index/value"
        fi
        return 0
    fi
    if [ -z "$__shlua_index" ]; then
        local __shlua_count
        __shlua_count="$(<"$__shlua_table/count")"
        __shlua_index=$((__shlua_count + 1))
        printf '%s' "$__shlua_index" > "$__shlua_table/count"
        mkdir "$__shlua_table/$__shlua_index"
    fi
    printf '%s' "$__shlua_type" > "$__shlua_table/$__shlua_index/type"
    printf '%s' "$__shlua_key" > "$__shlua_table/$__shlua_index/key"
    printf '%s' "$__shlua_value" > "$__shlua_table/$__shlua_index/value"
}

__shlua_table_new() {
    local __shlua_table
    __shlua_table="$(mktemp -d "$__shlua_table_root/value.XXXXXX")" || return 1
    printf '0' > "$__shlua_table/count"
    while [ "$#" -ge 4 ]; do
        __shlua_table_set "$__shlua_table" "$1" "$2" "$3" "$4" || return 1
        shift 4
    done
    printf '%s' "$__shlua_table"
}

__shlua_table_contains() {
    [ -n "$(__shlua_table_find "$1" "$2" "$3")" ]
}

__shlua_table_get() {
    local __shlua_index
    __shlua_index="$(__shlua_table_find "$1" "$2" "$3")"
    if [ -n "$__shlua_index" ]; then
        printf '%s' "$(<"$1/$__shlua_index/value")"
    fi
}

__shlua_table_length() {
    local __shlua_table="$1"
    local __shlua_length=0
    while __shlua_table_contains "$__shlua_table" n "$((__shlua_length + 1))"; do
        __shlua_length=$((__shlua_length + 1))
    done
    printf '%s' "$__shlua_length"
}

__shlua_length() {
    if [ -d "$1" ] && [ -f "$1/count" ]; then
        __shlua_table_length "$1"
    else
        printf '%s' "${#1}"
    fi
}

__shlua_table_entry_exists() {
    [ -f "$1/$2/type" ]
}

__shlua_table_entry_key() {
    printf '%s' "$(<"$1/$2/key")"
}

__shlua_table_entry_value() {
    printf '%s' "$(<"$1/$2/value")"
}

__shlua_table_concat() {
    local __shlua_table="$1"
    local __shlua_separator="${2-}"
    local __shlua_first="${3:-1}"
    local __shlua_last="${4:-$(__shlua_table_length "$__shlua_table")}"
    local __shlua_index="$__shlua_first"
    local __shlua_output=''
    while [ "$__shlua_index" -le "$__shlua_last" ]; do
        if ! __shlua_table_contains "$__shlua_table" n "$__shlua_index"; then
            printf 'ShLua table.concat error: invalid value at index %s\n' "$__shlua_index" >&2
            return 1
        fi
        if [ "$__shlua_index" -gt "$__shlua_first" ]; then
            __shlua_output="${__shlua_output}${__shlua_separator}"
        fi
        __shlua_output="${__shlua_output}$(__shlua_table_get "$__shlua_table" n "$__shlua_index")"
        __shlua_index=$((__shlua_index + 1))
    done
    printf '%s' "$__shlua_output"
}

__shlua_table_insert() {
    local __shlua_table="$1"
    local __shlua_length
    local __shlua_position
    local __shlua_value
    __shlua_length="$(__shlua_table_length "$__shlua_table")"
    if [ "$#" -eq 2 ]; then
        __shlua_position=$((__shlua_length + 1))
        __shlua_value="$2"
    else
        __shlua_position="$2"
        __shlua_value="$3"
    fi
    local __shlua_index="$__shlua_length"
    while [ "$__shlua_index" -ge "$__shlua_position" ]; do
        __shlua_table_set "$__shlua_table" n "$((__shlua_index + 1))" \
            "$(__shlua_table_get "$__shlua_table" n "$__shlua_index")" 1
        __shlua_index=$((__shlua_index - 1))
    done
    __shlua_table_set "$__shlua_table" n "$__shlua_position" "$__shlua_value" 1
}

__shlua_table_maxn() {
    local __shlua_table="$1"
    local __shlua_count
    local __shlua_index=1
    local __shlua_max=0
    __shlua_count="$(<"$__shlua_table/count")"
    while [ "$__shlua_index" -le "$__shlua_count" ]; do
        if [ -f "$__shlua_table/$__shlua_index/type" ] \
            && [ "$(<"$__shlua_table/$__shlua_index/type")" = 'n' ]; then
            local __shlua_key
            __shlua_key="$(<"$__shlua_table/$__shlua_index/key")"
            __shlua_max="$(LC_ALL=C awk -v current="$__shlua_max" -v key="$__shlua_key" \
                'BEGIN { if (key > 0 && key > current) print key; else print current }' </dev/null)"
        fi
        __shlua_index=$((__shlua_index + 1))
    done
    printf '%s' "$__shlua_max"
}

__shlua_table_remove() {
    local __shlua_table="$1"
    local __shlua_length
    local __shlua_position
    __shlua_length="$(__shlua_table_length "$__shlua_table")"
    __shlua_position="${2:-$__shlua_length}"
    if [ "$__shlua_position" -lt 1 ] || [ "$__shlua_position" -gt "$__shlua_length" ]; then
        return 0
    fi
    local __shlua_removed
    __shlua_removed="$(__shlua_table_get "$__shlua_table" n "$__shlua_position")"
    local __shlua_index="$__shlua_position"
    while [ "$__shlua_index" -lt "$__shlua_length" ]; do
        __shlua_table_set "$__shlua_table" n "$__shlua_index" \
            "$(__shlua_table_get "$__shlua_table" n "$((__shlua_index + 1))")" 1
        __shlua_index=$((__shlua_index + 1))
    done
    __shlua_table_set "$__shlua_table" n "$__shlua_length" '' 0
    printf '%s' "$__shlua_removed"
}

__shlua_table_truthy() {
    [ -n "$1" ] && [ "$1" != 'false' ]
}

__shlua_table_less() {
    if [[ "$1" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]] \
        && [[ "$2" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        LC_ALL=C awk -v left="$1" -v right="$2" 'BEGIN { exit !(left < right) }' </dev/null
    else
        [[ "$1" < "$2" ]]
    fi
}

__shlua_table_sort() {
    local __shlua_table="$1"
    local __shlua_comparator="${2-}"
    local __shlua_length
    __shlua_length="$(__shlua_table_length "$__shlua_table")"
    local __shlua_end="$__shlua_length"
    while [ "$__shlua_end" -gt 1 ]; do
        local __shlua_index=1
        while [ "$__shlua_index" -lt "$__shlua_end" ]; do
            local __shlua_left
            local __shlua_right
            local __shlua_swap=false
            __shlua_left="$(__shlua_table_get "$__shlua_table" n "$__shlua_index")"
            __shlua_right="$(__shlua_table_get "$__shlua_table" n "$((__shlua_index + 1))")"
            if [ -n "$__shlua_comparator" ]; then
                if __shlua_table_truthy "$(__shlua_call "$__shlua_comparator" "$__shlua_right" "$__shlua_left")"; then
                    __shlua_swap=true
                fi
            elif __shlua_table_less "$__shlua_right" "$__shlua_left"; then
                __shlua_swap=true
            fi
            if $__shlua_swap; then
                __shlua_table_set "$__shlua_table" n "$__shlua_index" "$__shlua_right" 1
                __shlua_table_set "$__shlua_table" n "$((__shlua_index + 1))" "$__shlua_left" 1
            fi
            __shlua_index=$((__shlua_index + 1))
        done
        __shlua_end=$((__shlua_end - 1))
    done
}]=]

return M
