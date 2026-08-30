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

M.source = [=[function __luash_table_new {
    @{
        __LuashTable = $true
        Entries = New-Object 'System.Collections.Generic.Dictionary[string,object]'
        Keys = New-Object 'System.Collections.Generic.Dictionary[string,object]'
    }
}

function __luash_table_key {
    param($Type, $Key)
    if ($Type -eq 'z' -or $null -eq $Key) { throw 'Luash table error: table index is nil' }
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

function __luash_table_set {
    param($Table, $Type, $Key, $Value, $Present = $true)
    $Encoded = __luash_table_key $Type $Key
    if (-not $Present -or $null -eq $Value) {
        [void] $Table.Entries.Remove($Encoded)
        [void] $Table.Keys.Remove($Encoded)
        return
    }
    $Table.Entries[$Encoded] = $Value
    $Table.Keys[$Encoded] = $Key
}

function __luash_table_contains {
    param($Table, $Type, $Key)
    $Table.Entries.ContainsKey((__luash_table_key $Type $Key))
}

function __luash_table_get {
    param($Table, $Type, $Key)
    $Encoded = __luash_table_key $Type $Key
    if ($Table.Entries.ContainsKey($Encoded)) { $Table.Entries[$Encoded] }
}

function __luash_table_length {
    param($Table)
    $Length = 0
    while (__luash_table_contains $Table 'n' ($Length + 1)) { $Length++ }
    $Length
}

function __luash_length {
    param($Value)
    if ($Value -is [hashtable] -and $Value.__LuashTable) { return __luash_table_length $Value }
    ([string] $Value).Length
}

function __luash_table_concat {
    param($Table, $Separator = '', $First = 1, $Last = $null)
    if ($null -eq $Last) { $Last = __luash_table_length $Table }
    $Parts = New-Object 'System.Collections.Generic.List[string]'
    for ($Index = [int] $First; $Index -le [int] $Last; $Index++) {
        if (-not (__luash_table_contains $Table 'n' $Index)) {
            throw "Luash table.concat error: invalid value at index $Index"
        }
        [void] $Parts.Add([string] (__luash_table_get $Table 'n' $Index))
    }
    [string]::Join([string] $Separator, $Parts.ToArray())
}

function __luash_table_insert {
    param($Table, $Position, $Value)
    $Length = __luash_table_length $Table
    if ($PSBoundParameters.Count -eq 2) {
        $Value = $Position
        $Position = $Length + 1
    }
    for ($Index = $Length; $Index -ge [int] $Position; $Index--) {
        __luash_table_set $Table 'n' ($Index + 1) (__luash_table_get $Table 'n' $Index)
    }
    __luash_table_set $Table 'n' ([int] $Position) $Value
}

function __luash_table_maxn {
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

function __luash_table_remove {
    param($Table, $Position = $null)
    $Length = __luash_table_length $Table
    if ($null -eq $Position) { $Position = $Length }
    if ([int] $Position -lt 1 -or [int] $Position -gt $Length) { return $null }
    $Removed = __luash_table_get $Table 'n' ([int] $Position)
    for ($Index = [int] $Position; $Index -lt $Length; $Index++) {
        __luash_table_set $Table 'n' $Index (__luash_table_get $Table 'n' ($Index + 1))
    }
    __luash_table_set $Table 'n' $Length $null $false
    $Removed
}

function __luash_table_truthy {
    param($Value)
    $null -ne $Value -and $Value -ne $false
}

function __luash_table_sort {
    param($Table, $Comparator = $null)
    $Length = __luash_table_length $Table
    for ($End = $Length; $End -gt 1; $End--) {
        for ($Index = 1; $Index -lt $End; $Index++) {
            $Left = __luash_table_get $Table 'n' $Index
            $Right = __luash_table_get $Table 'n' ($Index + 1)
            if ($null -ne $Comparator) {
                $Swap = __luash_table_truthy (__luash_call $Comparator @($Right, $Left))
            } else {
                $Swap = $Right -lt $Left
            }
            if ($Swap) {
                __luash_table_set $Table 'n' $Index $Right
                __luash_table_set $Table 'n' ($Index + 1) $Left
            }
        }
    }
}]=]

return M
