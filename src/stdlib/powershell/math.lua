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
    ["math.huge"] = "([double]::PositiveInfinity)",
    ["math.pi"] = "([Math]::PI)",
}

M.unsupported = {
    ["math.frexp"] = "returns multiple values",
    ["math.modf"] = "returns multiple values",
    ["math.random"] = "seeded Lua-compatible generator state is not implemented",
    ["math.randomseed"] = "seeded Lua-compatible generator state is not implemented",
}

M.source = [=[function __shlua_math_abs { param($Value) [Math]::Abs([double] $Value) }
function __shlua_math_acos { param($Value) [Math]::Acos([double] $Value) }
function __shlua_math_asin { param($Value) [Math]::Asin([double] $Value) }
function __shlua_math_atan { param($Value) [Math]::Atan([double] $Value) }
function __shlua_math_atan2 { param($Y, $X) [Math]::Atan2([double] $Y, [double] $X) }
function __shlua_math_ceil { param($Value) [Math]::Ceiling([double] $Value) }
function __shlua_math_cos { param($Value) [Math]::Cos([double] $Value) }
function __shlua_math_cosh { param($Value) [Math]::Cosh([double] $Value) }
function __shlua_math_deg { param($Value) ([double] $Value) * 180 / [Math]::PI }
function __shlua_math_exp { param($Value) [Math]::Exp([double] $Value) }
function __shlua_math_floor { param($Value) [Math]::Floor([double] $Value) }
function __shlua_math_fmod { param($X, $Y) ([double] $X) % ([double] $Y) }
function __shlua_math_ldexp { param($Mantissa, $Exponent) ([double] $Mantissa) * [Math]::Pow(2, [double] $Exponent) }
function __shlua_math_log { param($Value) [Math]::Log([double] $Value) }
function __shlua_math_log10 { param($Value) [Math]::Log10([double] $Value) }
function __shlua_math_max {
    param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Values)
    $Result = [double] $Values[0]
    foreach ($Value in $Values) { $Result = [Math]::Max($Result, [double] $Value) }
    $Result
}
function __shlua_math_min {
    param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Values)
    $Result = [double] $Values[0]
    foreach ($Value in $Values) { $Result = [Math]::Min($Result, [double] $Value) }
    $Result
}
function __shlua_math_pow { param($X, $Y) [Math]::Pow([double] $X, [double] $Y) }
function __shlua_math_rad { param($Value) ([double] $Value) * [Math]::PI / 180 }
function __shlua_math_sin { param($Value) [Math]::Sin([double] $Value) }
function __shlua_math_sinh { param($Value) [Math]::Sinh([double] $Value) }
function __shlua_math_sqrt { param($Value) [Math]::Sqrt([double] $Value) }
function __shlua_math_tan { param($Value) [Math]::Tan([double] $Value) }
function __shlua_math_tanh { param($Value) [Math]::Tanh([double] $Value) }]=]

return M
