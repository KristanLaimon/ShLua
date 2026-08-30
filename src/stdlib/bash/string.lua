local M = { name = "string" }

M.functions = {
    ["string.byte"] = "__luash_string_byte",
    ["string.char"] = "__luash_string_char",
    ["string.find"] = "__luash_string_find",
    ["string.format"] = "__luash_string_format",
    ["string.len"] = "__luash_string_len",
    ["string.lower"] = "__luash_string_lower",
    ["string.rep"] = "__luash_string_rep",
    ["string.reverse"] = "__luash_string_reverse",
    ["string.sub"] = "__luash_string_sub",
    ["string.upper"] = "__luash_string_upper",
}

M.unsupported = {
    ["string.dump"] = "requires Lua bytecode",
    ["string.gmatch"] = "returns an iterator and requires Lua pattern matching",
    ["string.gsub"] = "requires Lua pattern matching and returns multiple values",
    ["string.match"] = "requires Lua pattern matching and capture returns",
}

M.source = [[__luash_string_byte() {
    local __luash_value="$1"
    local __luash_index="${2:-1}"
    local __luash_length="${#__luash_value}"
    if [ "$__luash_index" -lt 0 ]; then
        __luash_index=$((__luash_length + __luash_index + 1))
    fi
    if [ "$__luash_index" -lt 1 ] || [ "$__luash_index" -gt "$__luash_length" ]; then
        return 0
    fi
    local __luash_character="${__luash_value:$((__luash_index - 1)):1}"
    LC_CTYPE=C printf '%d\n' "'$__luash_character"
}

__luash_string_char() {
    local __luash_result=''
    local __luash_code
    local __luash_octal
    for __luash_code in "$@"; do
        printf -v __luash_octal '%03o' "$__luash_code"
        printf -v __luash_result '%s%b' "$__luash_result" "\\$__luash_octal"
    done
    printf '%s\n' "$__luash_result"
}

__luash_string_find() {
    local __luash_value="$1"
    local __luash_needle="$2"
    local __luash_index="${3:-1}"
    local __luash_length="${#__luash_value}"
    if [ "$__luash_index" -lt 0 ]; then
        __luash_index=$((__luash_length + __luash_index + 1))
    fi
    if [ "$__luash_index" -lt 1 ]; then
        __luash_index=1
    fi
    local __luash_tail="${__luash_value:$((__luash_index - 1))}"
    case "$__luash_tail" in
        *"$__luash_needle"*)
            local __luash_prefix="${__luash_tail%%"$__luash_needle"*}"
            printf '%s\n' "$((__luash_index + ${#__luash_prefix}))"
            ;;
    esac
}

__luash_string_format() {
    local __luash_format="$1"
    shift
    LC_ALL=C printf "$__luash_format" "$@"
    printf '\n'
}

__luash_string_len() {
    printf '%s\n' "${#1}"
}

__luash_string_lower() {
    LC_ALL=C awk 'BEGIN { print tolower(ARGV[1]) }' "$1"
}

__luash_string_rep() {
    local __luash_value="$1"
    local __luash_count="$2"
    local __luash_result=''
    local __luash_index=0
    while [ "$__luash_index" -lt "$__luash_count" ]; do
        __luash_result="${__luash_result}${__luash_value}"
        __luash_index=$((__luash_index + 1))
    done
    printf '%s\n' "$__luash_result"
}

__luash_string_reverse() {
    local __luash_value="$1"
    local __luash_result=''
    local __luash_index=${#__luash_value}
    while [ "$__luash_index" -gt 0 ]; do
        __luash_index=$((__luash_index - 1))
        __luash_result="${__luash_result}${__luash_value:$__luash_index:1}"
    done
    printf '%s\n' "$__luash_result"
}

__luash_string_sub() {
    local __luash_value="$1"
    local __luash_start="$2"
    local __luash_end="${3:--1}"
    local __luash_length=${#__luash_value}
    if [ "$__luash_start" -lt 0 ]; then
        __luash_start=$((__luash_length + __luash_start + 1))
    fi
    if [ "$__luash_end" -lt 0 ]; then
        __luash_end=$((__luash_length + __luash_end + 1))
    fi
    if [ "$__luash_start" -lt 1 ]; then
        __luash_start=1
    fi
    if [ "$__luash_end" -gt "$__luash_length" ]; then
        __luash_end=$__luash_length
    fi
    if [ "$__luash_start" -gt "$__luash_end" ]; then
        printf '\n'
        return 0
    fi
    printf '%s\n' "${__luash_value:$((__luash_start - 1)):$((__luash_end - __luash_start + 1))}"
}

__luash_string_upper() {
    LC_ALL=C awk 'BEGIN { print toupper(ARGV[1]) }' "$1"
}]]

return M
