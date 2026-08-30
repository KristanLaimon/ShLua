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

M.source = [=[function __shlua_string_byte {
    param($Value, $Index = 1)
    $Text = [string] $Value
    $Position = [int] $Index
    if ($Position -lt 0) { $Position = $Text.Length + $Position + 1 }
    if ($Position -ge 1 -and $Position -le $Text.Length) { [int] [char] $Text[$Position - 1] }
}

function __shlua_string_char {
    param([Parameter(ValueFromRemainingArguments = $true)] [object[]] $Codes)
    $Builder = New-Object System.Text.StringBuilder
    foreach ($Code in $Codes) { [void] $Builder.Append([char] [int] $Code) }
    $Builder.ToString()
}

function __shlua_string_find {
    param($Value, $Needle, $Index = 1, $Plain = $false)
    $Text = [string] $Value
    $Position = [int] $Index
    if ($Position -lt 0) { $Position = $Text.Length + $Position + 1 }
    if ($Position -lt 1) { $Position = 1 }
    $Found = $Text.IndexOf([string] $Needle, $Position - 1, [StringComparison]::Ordinal)
    if ($Found -ge 0) { $Found + 1 }
}

function __shlua_string_format {
    param($Format, [Parameter(ValueFromRemainingArguments = $true)] [object[]] $Values)
    $Text = [string] $Format
    $Builder = New-Object System.Text.StringBuilder
    $Argument = 0
    $Index = 0
    while ($Index -lt $Text.Length) {
        if ($Text[$Index] -ne '%') {
            [void] $Builder.Append($Text[$Index])
            $Index++
            continue
        }
        if ($Index + 1 -lt $Text.Length -and $Text[$Index + 1] -eq '%') {
            [void] $Builder.Append('%')
            $Index += 2
            continue
        }
        $Tail = $Text.Substring($Index)
        $Match = [regex]::Match($Tail, '^%([0-9]*)(?:\.([0-9]+))?([cdeEfgGiouXxqs])')
        if (-not $Match.Success) { throw "unsupported string.format conversion near '$Tail'" }
        $Value = $Values[$Argument]
        $Precision = $Match.Groups[2].Value
        $Kind = $Match.Groups[3].Value
        if ($Kind -eq 's') {
            $Rendered = [string] $Value
        } elseif ($Kind -eq 'q') {
            $Rendered = '"' + ([string] $Value).Replace('\', '\\').Replace('"', '\"').Replace("`n", '\n') + '"'
        } elseif ($Kind -eq 'c') {
            $Rendered = [string] [char] [int] $Value
        } elseif ($Kind -match '[diouxX]') {
            if ($Kind -eq 'x') { $Rendered = ([long] $Value).ToString('x') }
            elseif ($Kind -eq 'X') { $Rendered = ([long] $Value).ToString('X') }
            else { $Rendered = ([long] $Value).ToString([Globalization.CultureInfo]::InvariantCulture) }
        } else {
            $NumberFormat = if ($Precision) { $Kind.ToUpperInvariant() + $Precision } else { $Kind.ToUpperInvariant() }
            $Rendered = ([double] $Value).ToString($NumberFormat, [Globalization.CultureInfo]::InvariantCulture)
        }
        [void] $Builder.Append($Rendered)
        $Argument++
        $Index += $Match.Length
    }
    $Builder.ToString()
}

function __shlua_string_len { param($Value) ([string] $Value).Length }
function __shlua_string_lower { param($Value) ([string] $Value).ToLowerInvariant() }
function __shlua_string_rep {
    param($Value, $Count)
    $Builder = New-Object System.Text.StringBuilder
    for ($Index = 0; $Index -lt [int] $Count; $Index++) { [void] $Builder.Append([string] $Value) }
    $Builder.ToString()
}
function __shlua_string_reverse {
    param($Value)
    $Text = [string] $Value
    $Builder = New-Object System.Text.StringBuilder
    for ($Index = $Text.Length - 1; $Index -ge 0; $Index--) { [void] $Builder.Append($Text[$Index]) }
    $Builder.ToString()
}
function __shlua_string_sub {
    param($Value, $Start, $End = -1)
    $Text = [string] $Value
    $First = [int] $Start
    $Last = [int] $End
    if ($First -lt 0) { $First = $Text.Length + $First + 1 }
    if ($Last -lt 0) { $Last = $Text.Length + $Last + 1 }
    if ($First -lt 1) { $First = 1 }
    if ($Last -gt $Text.Length) { $Last = $Text.Length }
    if ($First -gt $Last) { return '' }
    $Text.Substring($First - 1, $Last - $First + 1)
}
function __shlua_string_upper { param($Value) ([string] $Value).ToUpperInvariant() }]=]

return M
