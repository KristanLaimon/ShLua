local M = { name = "math" }

M.functions = {
    ["math.abs"] = "__luash_math_abs",
    ["math.acos"] = "__luash_math_acos",
    ["math.asin"] = "__luash_math_asin",
    ["math.atan"] = "__luash_math_atan",
    ["math.atan2"] = "__luash_math_atan2",
    ["math.ceil"] = "__luash_math_ceil",
    ["math.cos"] = "__luash_math_cos",
    ["math.cosh"] = "__luash_math_cosh",
    ["math.deg"] = "__luash_math_deg",
    ["math.exp"] = "__luash_math_exp",
    ["math.floor"] = "__luash_math_floor",
    ["math.fmod"] = "__luash_math_fmod",
    ["math.ldexp"] = "__luash_math_ldexp",
    ["math.log"] = "__luash_math_log",
    ["math.log10"] = "__luash_math_log10",
    ["math.max"] = "__luash_math_max",
    ["math.min"] = "__luash_math_min",
    ["math.pow"] = "__luash_math_pow",
    ["math.rad"] = "__luash_math_rad",
    ["math.sin"] = "__luash_math_sin",
    ["math.sinh"] = "__luash_math_sinh",
    ["math.sqrt"] = "__luash_math_sqrt",
    ["math.tan"] = "__luash_math_tan",
    ["math.tanh"] = "__luash_math_tanh",
}

M.constants = {
    ["math.huge"] = "1.7976931348623157e+308",
    ["math.pi"] = "3.14159265358979323846",
}

M.unsupported = {
    ["math.frexp"] = "returns multiple values",
    ["math.modf"] = "returns multiple values",
    ["math.random"] = "cannot preserve generator state through Bash command substitution",
    ["math.randomseed"] = "cannot preserve generator state through Bash command substitution",
}

M.dependencies = {}
for name, helper in pairs(M.functions) do
    if name ~= "math.max" and name ~= "math.min" then
        M.dependencies[helper] = { "__luash_math_eval" }
    end
end

M.source = [[__luash_math_eval() {
    local __luash_program="$1"
    local __luash_x="${2:-0}"
    local __luash_y="${3:-0}"
    LC_ALL=C awk -v x="$__luash_x" -v y="$__luash_y" "$__luash_program" </dev/null
}

__luash_math_abs() {
    __luash_math_eval 'BEGIN { print x < 0 ? -x : x }' "$1"
}

__luash_math_acos() {
    __luash_math_eval 'BEGIN { print atan2(sqrt(1 - x * x), x) }' "$1"
}

__luash_math_asin() {
    __luash_math_eval 'BEGIN { print atan2(x, sqrt(1 - x * x)) }' "$1"
}

__luash_math_atan() {
    __luash_math_eval 'BEGIN { print atan2(x, 1) }' "$1"
}

__luash_math_atan2() {
    __luash_math_eval 'BEGIN { print atan2(x, y) }' "$1" "$2"
}

__luash_math_ceil() {
    __luash_math_eval 'BEGIN { i = int(x); print (x > i ? i + 1 : i) }' "$1"
}

__luash_math_cos() {
    __luash_math_eval 'BEGIN { print cos(x) }' "$1"
}

__luash_math_cosh() {
    __luash_math_eval 'BEGIN { print (exp(x) + exp(-x)) / 2 }' "$1"
}

__luash_math_deg() {
    __luash_math_eval 'BEGIN { print x * 180 / atan2(0, -1) }' "$1"
}

__luash_math_exp() {
    __luash_math_eval 'BEGIN { print exp(x) }' "$1"
}

__luash_math_floor() {
    __luash_math_eval 'BEGIN { i = int(x); print (x < i ? i - 1 : i) }' "$1"
}

__luash_math_fmod() {
    __luash_math_eval 'BEGIN { print x - int(x / y) * y }' "$1" "$2"
}

__luash_math_ldexp() {
    __luash_math_eval 'BEGIN { print x * (2 ^ y) }' "$1" "$2"
}

__luash_math_log() {
    __luash_math_eval 'BEGIN { print log(x) }' "$1"
}

__luash_math_log10() {
    __luash_math_eval 'BEGIN { print log(x) / log(10) }' "$1"
}

__luash_math_max() {
    LC_ALL=C awk '
        BEGIN {
            value = ARGV[1]
            for (i = 2; i < ARGC; i++) if (ARGV[i] > value) value = ARGV[i]
            print value
        }
    ' "$@"
}

__luash_math_min() {
    LC_ALL=C awk '
        BEGIN {
            value = ARGV[1]
            for (i = 2; i < ARGC; i++) if (ARGV[i] < value) value = ARGV[i]
            print value
        }
    ' "$@"
}

__luash_math_pow() {
    __luash_math_eval 'BEGIN { print x ^ y }' "$1" "$2"
}

__luash_math_rad() {
    __luash_math_eval 'BEGIN { print x * atan2(0, -1) / 180 }' "$1"
}

__luash_math_sin() {
    __luash_math_eval 'BEGIN { print sin(x) }' "$1"
}

__luash_math_sinh() {
    __luash_math_eval 'BEGIN { print (exp(x) - exp(-x)) / 2 }' "$1"
}

__luash_math_sqrt() {
    __luash_math_eval 'BEGIN { print sqrt(x) }' "$1"
}

__luash_math_tan() {
    __luash_math_eval 'BEGIN { print sin(x) / cos(x) }' "$1"
}

__luash_math_tanh() {
    __luash_math_eval 'BEGIN { print (exp(x) - exp(-x)) / (exp(x) + exp(-x)) }' "$1"
}]]

return M
