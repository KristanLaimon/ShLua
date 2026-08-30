local M = { name = "base" }

M.functions = {
    ["tonumber"] = "__luash_tonumber",
    ["tostring"] = "__luash_tostring",
    ["type"] = "__luash_type",
}

M.source = [=[function __luash_tostring {
    param($Value)
    if ($null -eq $Value) { return 'nil' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
}

function __luash_tonumber {
    param($Value, $Base = 10)
    if ([int] $Base -ne 10) {
        try { return [Convert]::ToInt64([string] $Value, [int] $Base) } catch { return $null }
    }
    $Result = 0.0
    if ([double]::TryParse(
        [string] $Value,
        [Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,
        [ref] $Result
    )) { $Result }
}

function __luash_type {
    param($Value)
    if ($null -eq $Value) { return 'nil' }
    if ($Value -is [bool]) { return 'boolean' }
    if (
        $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]
    ) { return 'number' }
    if ($Value -is [hashtable] -and $Value.Function) { return 'function' }
    if ($Value -is [hashtable] -and $Value.__LuashTable) { return 'table' }
    if ($Value -is [array] -or $Value -is [hashtable]) { return 'table' }
    'string'
}]=]

return M
