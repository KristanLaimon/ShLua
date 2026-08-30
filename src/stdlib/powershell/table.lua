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

M.callHelpers = {
    ipairs = { "__shlua_table_contains", "__shlua_table_get" },
}

M.dependencies = {
    __shlua_table_set = { "__shlua_table_key" },
    __shlua_table_contains = { "__shlua_table_key" },
    __shlua_table_get = { "__shlua_table_key" },
    __shlua_table_length = { "__shlua_table_contains" },
    __shlua_length = { "__shlua_table_length" },
    __shlua_table_concat = { "__shlua_table_length", "__shlua_table_contains", "__shlua_table_get" },
    __shlua_table_insert = { "__shlua_table_length", "__shlua_table_set", "__shlua_table_get" },
    __shlua_table_remove = { "__shlua_table_length", "__shlua_table_get", "__shlua_table_set" },
    __shlua_table_sort = { "__shlua_table_length", "__shlua_table_get", "__shlua_table_truthy", "__shlua_table_set" },
}

M.source = [=[function __shlua_table_new {
    @{
        __ShLuaTable = $true
        Entries = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        Keys = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    }
}

function __shlua_table_key {
    param($Type, $Key)
    if ($Type -eq 'z' -or $null -eq $Key) { throw 'ShLua table error: table index is nil' }
    if (-not $Type) {
        if ($Key -is [byte] -or $Key -is [int16] -or $Key -is [int32] -or $Key -is [int64] -or
            $Key -is [single] -or $Key -is [double] -or $Key -is [decimal]) { $Type = 'n' }
        elseif ($Key -is [bool]) { $Type = 'b' }
        else { $Type = 's' }
    }
    if ($Type -eq 'n') {
        return 'n:' + [Convert]::ToString([double] $Key, [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Type -eq 'b') { return 'b:' + ([bool] $Key).ToString().ToLowerInvariant() }
    's:' + [string] $Key
}

function __shlua_table_set {
    param($Table, $Type, $Key, $Value, $Present = $true)
    $Encoded = __shlua_table_key $Type $Key
    if (-not $Present -or $null -eq $Value) {
        [void] $Table.Entries.Remove($Encoded)
        [void] $Table.Keys.Remove($Encoded)
        return
    }
    $Table.Entries[$Encoded] = $Value
    $Table.Keys[$Encoded] = $Key
}

function __shlua_table_contains {
    param($Table, $Type, $Key)
    $Table.Entries.ContainsKey((__shlua_table_key $Type $Key))
}

function __shlua_table_get {
    param($Table, $Type, $Key)
    $Encoded = __shlua_table_key $Type $Key
    if ($Table.Entries.ContainsKey($Encoded)) { $Table.Entries[$Encoded] }
}

function __shlua_table_length {
    param($Table)
    $Length = 0
    while (__shlua_table_contains $Table 'n' ($Length + 1)) { $Length++ }
    $Length
}

function __shlua_length {
    param($Value)
    if ($Value -is [hashtable] -and $Value.__ShLuaTable) { return __shlua_table_length $Value }
    ([string] $Value).Length
}

function __shlua_table_concat {
    param($Table, $Separator = '', $First = 1, $Last = $null)
    if ($null -eq $Last) { $Last = __shlua_table_length $Table }
    $Parts = New-Object 'System.Collections.Generic.List[string]'
    for ($Index = [int] $First; $Index -le [int] $Last; $Index++) {
        if (-not (__shlua_table_contains $Table 'n' $Index)) {
            throw "ShLua table.concat error: invalid value at index $Index"
        }
        [void] $Parts.Add([string] (__shlua_table_get $Table 'n' $Index))
    }
    [string]::Join([string] $Separator, $Parts.ToArray())
}

function __shlua_table_insert {
    param($Table, $Position, $Value)
    $Length = __shlua_table_length $Table
    if ($PSBoundParameters.Count -eq 2) {
        $Value = $Position
        $Position = $Length + 1
    }
    for ($Index = $Length; $Index -ge [int] $Position; $Index--) {
        __shlua_table_set $Table 'n' ($Index + 1) (__shlua_table_get $Table 'n' $Index)
    }
    __shlua_table_set $Table 'n' ([int] $Position) $Value
}

function __shlua_table_maxn {
    param($Table)
    $Maximum = 0.0
    foreach ($Encoded in @($Table.Entries.Keys)) {
        if ($Encoded.StartsWith('n:')) {
            $Key = [double] $Table.Keys[$Encoded]
            if ($Key -gt 0 -and $Key -gt $Maximum) { $Maximum = $Key }
        }
    }
    $Maximum
}

function __shlua_table_remove {
    param($Table, $Position = $null)
    $Length = __shlua_table_length $Table
    if ($null -eq $Position) { $Position = $Length }
    if ([int] $Position -lt 1 -or [int] $Position -gt $Length) { return $null }
    $Removed = __shlua_table_get $Table 'n' ([int] $Position)
    for ($Index = [int] $Position; $Index -lt $Length; $Index++) {
        __shlua_table_set $Table 'n' $Index (__shlua_table_get $Table 'n' ($Index + 1))
    }
    __shlua_table_set $Table 'n' $Length $null $false
    $Removed
}

function __shlua_table_truthy {
    param($Value)
    $null -ne $Value -and $Value -ne $false
}

function __shlua_table_sort {
    param($Table, $Comparator = $null)
    $Length = __shlua_table_length $Table
    for ($End = $Length; $End -gt 1; $End--) {
        for ($Index = 1; $Index -lt $End; $Index++) {
            $Left = __shlua_table_get $Table 'n' $Index
            $Right = __shlua_table_get $Table 'n' ($Index + 1)
            if ($null -ne $Comparator) {
                $Swap = __shlua_table_truthy (__shlua_call $Comparator @($Right, $Left))
            } else {
                $Swap = $Right -lt $Left
            }
            if ($Swap) {
                __shlua_table_set $Table 'n' $Index $Right
                __shlua_table_set $Table 'n' ($Index + 1) $Left
            }
        }
    }
}]=]

return M
