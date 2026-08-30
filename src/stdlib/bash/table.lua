local M = { name = "table" }

M.functions = {
    ["table.concat"] = "__luash_table_concat",
    ["table.insert"] = "__luash_table_insert",
    ["table.maxn"] = "__luash_table_maxn",
    ["table.remove"] = "__luash_table_remove",
    ["table.sort"] = "__luash_table_sort",
}

M.unsupported = {
    pairs = "pairs is supported only as the iterator of a generic for loop",
    ipairs = "ipairs is supported only as the iterator of a generic for loop",
}

M.source = [=[__luash_table_root="$(mktemp -d "${TMPDIR:-/tmp}/luash-table.XXXXXX")" || exit 1
__luash_table_cleanup() {
    rm -rf -- "$__luash_table_root"
}
trap '__luash_table_cleanup' EXIT

__luash_table_infer_key_type() {
    if [[ "$1" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        printf 'n'
    else
        printf 's'
    fi
}

__luash_table_normalize_number() {
    local __luash_value="$1"
    local __luash_sign=''
    if [[ "$__luash_value" =~ ^[-+]?[0-9]+$ ]]; then
        case "$__luash_value" in
            -*) __luash_sign='-'; __luash_value="${__luash_value#-}" ;;
            +*) __luash_value="${__luash_value#+}" ;;
        esac
        while [ "${#__luash_value}" -gt 1 ] && [ "${__luash_value#0}" != "$__luash_value" ]; do
            __luash_value="${__luash_value#0}"
        done
        if [ "$__luash_value" = '0' ]; then
            __luash_sign=''
        fi
        printf '%s%s' "$__luash_sign" "$__luash_value"
    else
        LC_ALL=C awk -v value="$__luash_value" 'BEGIN { printf "%.15g", value + 0 }' </dev/null
    fi
}

__luash_table_find() {
    local __luash_table="$1"
    local __luash_type="$2"
    local __luash_key="$3"
    if [ -z "$__luash_type" ]; then
        __luash_type="$(__luash_table_infer_key_type "$__luash_key")"
    fi
    if [ "$__luash_type" = 'z' ]; then
        return 0
    elif [ "$__luash_type" = 'n' ]; then
        __luash_key="$(__luash_table_normalize_number "$__luash_key")"
    fi

    local __luash_count
    local __luash_index=1
    __luash_count="$(<"$__luash_table/count")"
    while [ "$__luash_index" -le "$__luash_count" ]; do
        if [ -f "$__luash_table/$__luash_index/type" ] \
            && [ "$(<"$__luash_table/$__luash_index/type")" = "$__luash_type" ] \
            && [ "$(<"$__luash_table/$__luash_index/key")" = "$__luash_key" ]; then
            printf '%s' "$__luash_index"
            return 0
        fi
        __luash_index=$((__luash_index + 1))
    done
}

__luash_table_set() {
    local __luash_table="$1"
    local __luash_type="$2"
    local __luash_key="$3"
    local __luash_value="$4"
    local __luash_present="${5:-1}"
    if [ "$__luash_type" = 'z' ]; then
        printf 'Luash table error: table index is nil\n' >&2
        return 1
    fi
    if [ -z "$__luash_type" ]; then
        __luash_type="$(__luash_table_infer_key_type "$__luash_key")"
    fi
    if [ "$__luash_type" = 'n' ]; then
        __luash_key="$(__luash_table_normalize_number "$__luash_key")"
    fi

    local __luash_index
    __luash_index="$(__luash_table_find "$__luash_table" "$__luash_type" "$__luash_key")"
    if [ "$__luash_present" = '0' ]; then
        if [ -n "$__luash_index" ]; then
            rm -f -- "$__luash_table/$__luash_index/type" "$__luash_table/$__luash_index/key" \
                "$__luash_table/$__luash_index/value"
        fi
        return 0
    fi
    if [ -z "$__luash_index" ]; then
        local __luash_count
        __luash_count="$(<"$__luash_table/count")"
        __luash_index=$((__luash_count + 1))
        printf '%s' "$__luash_index" > "$__luash_table/count"
        mkdir "$__luash_table/$__luash_index"
    fi
    printf '%s' "$__luash_type" > "$__luash_table/$__luash_index/type"
    printf '%s' "$__luash_key" > "$__luash_table/$__luash_index/key"
    printf '%s' "$__luash_value" > "$__luash_table/$__luash_index/value"
}

__luash_table_new() {
    local __luash_table
    __luash_table="$(mktemp -d "$__luash_table_root/value.XXXXXX")" || return 1
    printf '0' > "$__luash_table/count"
    while [ "$#" -ge 4 ]; do
        __luash_table_set "$__luash_table" "$1" "$2" "$3" "$4" || return 1
        shift 4
    done
    printf '%s' "$__luash_table"
}

__luash_table_contains() {
    [ -n "$(__luash_table_find "$1" "$2" "$3")" ]
}

__luash_table_get() {
    local __luash_index
    __luash_index="$(__luash_table_find "$1" "$2" "$3")"
    if [ -n "$__luash_index" ]; then
        printf '%s' "$(<"$1/$__luash_index/value")"
    fi
}

__luash_table_length() {
    local __luash_table="$1"
    local __luash_length=0
    while __luash_table_contains "$__luash_table" n "$((__luash_length + 1))"; do
        __luash_length=$((__luash_length + 1))
    done
    printf '%s' "$__luash_length"
}

__luash_length() {
    if [ -d "$1" ] && [ -f "$1/count" ]; then
        __luash_table_length "$1"
    else
        printf '%s' "${#1}"
    fi
}

__luash_table_entry_exists() {
    [ -f "$1/$2/type" ]
}

__luash_table_entry_key() {
    printf '%s' "$(<"$1/$2/key")"
}

__luash_table_entry_value() {
    printf '%s' "$(<"$1/$2/value")"
}

__luash_table_concat() {
    local __luash_table="$1"
    local __luash_separator="${2-}"
    local __luash_first="${3:-1}"
    local __luash_last="${4:-$(__luash_table_length "$__luash_table")}"
    local __luash_index="$__luash_first"
    local __luash_output=''
    while [ "$__luash_index" -le "$__luash_last" ]; do
        if ! __luash_table_contains "$__luash_table" n "$__luash_index"; then
            printf 'Luash table.concat error: invalid value at index %s\n' "$__luash_index" >&2
            return 1
        fi
        if [ "$__luash_index" -gt "$__luash_first" ]; then
            __luash_output="${__luash_output}${__luash_separator}"
        fi
        __luash_output="${__luash_output}$(__luash_table_get "$__luash_table" n "$__luash_index")"
        __luash_index=$((__luash_index + 1))
    done
    printf '%s' "$__luash_output"
}

__luash_table_insert() {
    local __luash_table="$1"
    local __luash_length
    local __luash_position
    local __luash_value
    __luash_length="$(__luash_table_length "$__luash_table")"
    if [ "$#" -eq 2 ]; then
        __luash_position=$((__luash_length + 1))
        __luash_value="$2"
    else
        __luash_position="$2"
        __luash_value="$3"
    fi
    local __luash_index="$__luash_length"
    while [ "$__luash_index" -ge "$__luash_position" ]; do
        __luash_table_set "$__luash_table" n "$((__luash_index + 1))" \
            "$(__luash_table_get "$__luash_table" n "$__luash_index")" 1
        __luash_index=$((__luash_index - 1))
    done
    __luash_table_set "$__luash_table" n "$__luash_position" "$__luash_value" 1
}

__luash_table_maxn() {
    local __luash_table="$1"
    local __luash_count
    local __luash_index=1
    local __luash_max=0
    __luash_count="$(<"$__luash_table/count")"
    while [ "$__luash_index" -le "$__luash_count" ]; do
        if [ -f "$__luash_table/$__luash_index/type" ] \
            && [ "$(<"$__luash_table/$__luash_index/type")" = 'n' ]; then
            local __luash_key
            __luash_key="$(<"$__luash_table/$__luash_index/key")"
            __luash_max="$(LC_ALL=C awk -v current="$__luash_max" -v key="$__luash_key" \
                'BEGIN { if (key > 0 && key > current) print key; else print current }' </dev/null)"
        fi
        __luash_index=$((__luash_index + 1))
    done
    printf '%s' "$__luash_max"
}

__luash_table_remove() {
    local __luash_table="$1"
    local __luash_length
    local __luash_position
    __luash_length="$(__luash_table_length "$__luash_table")"
    __luash_position="${2:-$__luash_length}"
    if [ "$__luash_position" -lt 1 ] || [ "$__luash_position" -gt "$__luash_length" ]; then
        return 0
    fi
    local __luash_removed
    __luash_removed="$(__luash_table_get "$__luash_table" n "$__luash_position")"
    local __luash_index="$__luash_position"
    while [ "$__luash_index" -lt "$__luash_length" ]; do
        __luash_table_set "$__luash_table" n "$__luash_index" \
            "$(__luash_table_get "$__luash_table" n "$((__luash_index + 1))")" 1
        __luash_index=$((__luash_index + 1))
    done
    __luash_table_set "$__luash_table" n "$__luash_length" '' 0
    printf '%s' "$__luash_removed"
}

__luash_table_truthy() {
    [ -n "$1" ] && [ "$1" != 'false' ]
}

__luash_table_less() {
    if [[ "$1" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]] \
        && [[ "$2" =~ ^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        LC_ALL=C awk -v left="$1" -v right="$2" 'BEGIN { exit !(left < right) }' </dev/null
    else
        [[ "$1" < "$2" ]]
    fi
}

__luash_table_sort() {
    local __luash_table="$1"
    local __luash_comparator="${2-}"
    local __luash_length
    __luash_length="$(__luash_table_length "$__luash_table")"
    local __luash_end="$__luash_length"
    while [ "$__luash_end" -gt 1 ]; do
        local __luash_index=1
        while [ "$__luash_index" -lt "$__luash_end" ]; do
            local __luash_left
            local __luash_right
            local __luash_swap=false
            __luash_left="$(__luash_table_get "$__luash_table" n "$__luash_index")"
            __luash_right="$(__luash_table_get "$__luash_table" n "$((__luash_index + 1))")"
            if [ -n "$__luash_comparator" ]; then
                if __luash_table_truthy "$(__luash_call "$__luash_comparator" "$__luash_right" "$__luash_left")"; then
                    __luash_swap=true
                fi
            elif __luash_table_less "$__luash_right" "$__luash_left"; then
                __luash_swap=true
            fi
            if $__luash_swap; then
                __luash_table_set "$__luash_table" n "$__luash_index" "$__luash_right" 1
                __luash_table_set "$__luash_table" n "$((__luash_index + 1))" "$__luash_left" 1
            fi
            __luash_index=$((__luash_index + 1))
        done
        __luash_end=$((__luash_end - 1))
    done
}]=]

return M
