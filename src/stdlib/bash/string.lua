local M = { name = "string" }

M.functions = {
    ["string.byte"] = "__shlua_string_byte",
    ["string.char"] = "__shlua_string_char",
    ["string.find"] = "__shlua_string_find",
    ["string.format"] = "__shlua_string_format",
    ["string.len"] = "__shlua_string_len",
    ["string.lower"] = "__shlua_string_lower",
    ["string.rep"] = "__shlua_string_rep",
    ["string.reverse"] = "__shlua_string_reverse",
    ["string.sub"] = "__shlua_string_sub",
    ["string.upper"] = "__shlua_string_upper",
}

M.unsupported = {
    ["string.dump"] = "requires Lua bytecode",
    ["string.gmatch"] = "returns an iterator and requires Lua pattern matching",
    ["string.gsub"] = "requires Lua pattern matching and returns multiple values",
    ["string.match"] = "requires Lua pattern matching and capture returns",
}

M.source = [[__shlua_string_byte() {
    local __shlua_value="$1"
    local __shlua_index="${2:-1}"
    local __shlua_length="${#__shlua_value}"
    if [ "$__shlua_index" -lt 0 ]; then
        __shlua_index=$((__shlua_length + __shlua_index + 1))
    fi
    if [ "$__shlua_index" -lt 1 ] || [ "$__shlua_index" -gt "$__shlua_length" ]; then
        return 0
    fi
    local __shlua_character="${__shlua_value:$((__shlua_index - 1)):1}"
    LC_CTYPE=C printf '%d\n' "'$__shlua_character"
}

__shlua_string_char() {
    local __shlua_result=''
    local __shlua_code
    local __shlua_octal
    for __shlua_code in "$@"; do
        printf -v __shlua_octal '%03o' "$__shlua_code"
        printf -v __shlua_result '%s%b' "$__shlua_result" "\\$__shlua_octal"
    done
    printf '%s\n' "$__shlua_result"
}

__shlua_string_find() {
    local __shlua_value="$1"
    local __shlua_needle="$2"
    local __shlua_index="${3:-1}"
    local __shlua_length="${#__shlua_value}"
    if [ "$__shlua_index" -lt 0 ]; then
        __shlua_index=$((__shlua_length + __shlua_index + 1))
    fi
    if [ "$__shlua_index" -lt 1 ]; then
        __shlua_index=1
    fi
    local __shlua_tail="${__shlua_value:$((__shlua_index - 1))}"
    case "$__shlua_tail" in
        *"$__shlua_needle"*)
            local __shlua_prefix="${__shlua_tail%%"$__shlua_needle"*}"
            printf '%s\n' "$((__shlua_index + ${#__shlua_prefix}))"
            ;;
    esac
}

__shlua_string_format() {
    local __shlua_format="$1"
    shift
    LC_ALL=C printf "$__shlua_format" "$@"
    printf '\n'
}

__shlua_string_len() {
    printf '%s\n' "${#1}"
}

__shlua_string_lower() {
    LC_ALL=C awk 'BEGIN { print tolower(ARGV[1]) }' "$1"
}

__shlua_string_rep() {
    local __shlua_value="$1"
    local __shlua_count="$2"
    local __shlua_result=''
    local __shlua_index=0
    while [ "$__shlua_index" -lt "$__shlua_count" ]; do
        __shlua_result="${__shlua_result}${__shlua_value}"
        __shlua_index=$((__shlua_index + 1))
    done
    printf '%s\n' "$__shlua_result"
}

__shlua_string_reverse() {
    local __shlua_value="$1"
    local __shlua_result=''
    local __shlua_index=${#__shlua_value}
    while [ "$__shlua_index" -gt 0 ]; do
        __shlua_index=$((__shlua_index - 1))
        __shlua_result="${__shlua_result}${__shlua_value:$__shlua_index:1}"
    done
    printf '%s\n' "$__shlua_result"
}

__shlua_string_sub() {
    local __shlua_value="$1"
    local __shlua_start="$2"
    local __shlua_end="${3:--1}"
    local __shlua_length=${#__shlua_value}
    if [ "$__shlua_start" -lt 0 ]; then
        __shlua_start=$((__shlua_length + __shlua_start + 1))
    fi
    if [ "$__shlua_end" -lt 0 ]; then
        __shlua_end=$((__shlua_length + __shlua_end + 1))
    fi
    if [ "$__shlua_start" -lt 1 ]; then
        __shlua_start=1
    fi
    if [ "$__shlua_end" -gt "$__shlua_length" ]; then
        __shlua_end=$__shlua_length
    fi
    if [ "$__shlua_start" -gt "$__shlua_end" ]; then
        printf '\n'
        return 0
    fi
    printf '%s\n' "${__shlua_value:$((__shlua_start - 1)):$((__shlua_end - __shlua_start + 1))}"
}

__shlua_string_upper() {
    LC_ALL=C awk 'BEGIN { print toupper(ARGV[1]) }' "$1"
}]]

return M
