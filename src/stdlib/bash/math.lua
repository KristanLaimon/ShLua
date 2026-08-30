local M = { name = "math" }

M.functions = {
    ["math.abs"] = "__shlua_math_abs",
    ["math.acos"] = "__shlua_math_acos",
    ["math.asin"] = "__shlua_math_asin",
    ["math.atan"] = "__shlua_math_atan",
    ["math.atan2"] = "__shlua_math_atan2",
    ["math.ceil"] = "__shlua_math_ceil",
    ["math.cos"] = "__shlua_math_cos",
    ["math.cosh"] = "__shlua_math_cosh",
    ["math.deg"] = "__shlua_math_deg",
    ["math.exp"] = "__shlua_math_exp",
    ["math.floor"] = "__shlua_math_floor",
    ["math.fmod"] = "__shlua_math_fmod",
    ["math.ldexp"] = "__shlua_math_ldexp",
    ["math.log"] = "__shlua_math_log",
    ["math.log10"] = "__shlua_math_log10",
    ["math.max"] = "__shlua_math_max",
    ["math.min"] = "__shlua_math_min",
    ["math.pow"] = "__shlua_math_pow",
    ["math.rad"] = "__shlua_math_rad",
    ["math.sin"] = "__shlua_math_sin",
    ["math.sinh"] = "__shlua_math_sinh",
    ["math.sqrt"] = "__shlua_math_sqrt",
    ["math.tan"] = "__shlua_math_tan",
    ["math.tanh"] = "__shlua_math_tanh",
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
        M.dependencies[helper] = { "__shlua_math_eval" }
    end
end

M.source = [[__shlua_math_eval() {
    local __shlua_program="$1"
    local __shlua_x="${2:-0}"
    local __shlua_y="${3:-0}"
    LC_ALL=C awk -v x="$__shlua_x" -v y="$__shlua_y" "$__shlua_program" </dev/null
}

__shlua_math_abs() {
    __shlua_math_eval 'BEGIN { print x < 0 ? -x : x }' "$1"
}

__shlua_math_acos() {
    __shlua_math_eval 'BEGIN { print atan2(sqrt(1 - x * x), x) }' "$1"
}

__shlua_math_asin() {
    __shlua_math_eval 'BEGIN { print atan2(x, sqrt(1 - x * x)) }' "$1"
}

__shlua_math_atan() {
    __shlua_math_eval 'BEGIN { print atan2(x, 1) }' "$1"
}

__shlua_math_atan2() {
    __shlua_math_eval 'BEGIN { print atan2(x, y) }' "$1" "$2"
}

__shlua_math_ceil() {
    __shlua_math_eval 'BEGIN { i = int(x); print (x > i ? i + 1 : i) }' "$1"
}

__shlua_math_cos() {
    __shlua_math_eval 'BEGIN { print cos(x) }' "$1"
}

__shlua_math_cosh() {
    __shlua_math_eval 'BEGIN { print (exp(x) + exp(-x)) / 2 }' "$1"
}

__shlua_math_deg() {
    __shlua_math_eval 'BEGIN { print x * 180 / atan2(0, -1) }' "$1"
}

__shlua_math_exp() {
    __shlua_math_eval 'BEGIN { print exp(x) }' "$1"
}

__shlua_math_floor() {
    __shlua_math_eval 'BEGIN { i = int(x); print (x < i ? i - 1 : i) }' "$1"
}

__shlua_math_fmod() {
    __shlua_math_eval 'BEGIN { print x - int(x / y) * y }' "$1" "$2"
}

__shlua_math_ldexp() {
    __shlua_math_eval 'BEGIN { print x * (2 ^ y) }' "$1" "$2"
}

__shlua_math_log() {
    __shlua_math_eval 'BEGIN { print log(x) }' "$1"
}

__shlua_math_log10() {
    __shlua_math_eval 'BEGIN { print log(x) / log(10) }' "$1"
}

__shlua_math_max() {
    LC_ALL=C awk '
        BEGIN {
            value = ARGV[1]
            for (i = 2; i < ARGC; i++) if (ARGV[i] > value) value = ARGV[i]
            print value
        }
    ' "$@"
}

__shlua_math_min() {
    LC_ALL=C awk '
        BEGIN {
            value = ARGV[1]
            for (i = 2; i < ARGC; i++) if (ARGV[i] < value) value = ARGV[i]
            print value
        }
    ' "$@"
}

__shlua_math_pow() {
    __shlua_math_eval 'BEGIN { print x ^ y }' "$1" "$2"
}

__shlua_math_rad() {
    __shlua_math_eval 'BEGIN { print x * atan2(0, -1) / 180 }' "$1"
}

__shlua_math_sin() {
    __shlua_math_eval 'BEGIN { print sin(x) }' "$1"
}

__shlua_math_sinh() {
    __shlua_math_eval 'BEGIN { print (exp(x) - exp(-x)) / 2 }' "$1"
}

__shlua_math_sqrt() {
    __shlua_math_eval 'BEGIN { print sqrt(x) }' "$1"
}

__shlua_math_tan() {
    __shlua_math_eval 'BEGIN { print sin(x) / cos(x) }' "$1"
}

__shlua_math_tanh() {
    __shlua_math_eval 'BEGIN { print (exp(x) - exp(-x)) / (exp(x) + exp(-x)) }' "$1"
}]]

return M
