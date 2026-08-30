local M = { name = "os" }

M.functions = {
    ["os.clock"] = "__shlua_os_clock",
    ["os.date"] = "__shlua_os_date",
    ["os.difftime"] = "__shlua_os_difftime",
    ["os.execute"] = "__shlua_os_execute",
    ["os.exit"] = "__shlua_os_exit",
    ["os.getenv"] = "__shlua_os_getenv",
    ["os.remove"] = "__shlua_os_remove",
    ["os.rename"] = "__shlua_os_rename",
    ["os.time"] = "__shlua_os_time",
    ["os.tmpname"] = "__shlua_os_tmpname",
}

M.unsupported = {
    ["os.setlocale"] = "locale mutation is not portable across target shells",
}

M.prefix = [[$script:__shlua_os_clock = [Diagnostics.Stopwatch]::StartNew()]]
M.prefixHelpers = { __shlua_os_clock = true }

M.source = [=[$script:__shlua_os_clock = [Diagnostics.Stopwatch]::StartNew()
function __shlua_os_clock { $script:__shlua_os_clock.Elapsed.TotalSeconds }
function __shlua_os_date {
    param($Format = '%c', $Time = $null)
    $Epoch = [DateTime]::SpecifyKind([datetime] '1970-01-01', [DateTimeKind]::Utc)
    $Value = if ($null -eq $Time) { Get-Date } else { $Epoch.AddSeconds([double] $Time).ToLocalTime() }
    if ($Format -eq '%c') { return $Value.ToString() }
    $Converted = ([string] $Format).Replace('%Y', 'yyyy').Replace('%m', 'MM').Replace('%d', 'dd')
    $Converted = $Converted.Replace('%H', 'HH').Replace('%M', 'mm').Replace('%S', 'ss')
    $Value.ToString($Converted, [Globalization.CultureInfo]::InvariantCulture)
}
function __shlua_os_difftime { param($First, $Second) ([double] $First) - ([double] $Second) }
function __shlua_os_execute {
    param($Command)
    if ($null -eq $Command) { return 0 }
    & cmd.exe /d /s /c ([string] $Command)
    $LASTEXITCODE
}
function __shlua_os_exit { param($Code = 0) exit ([int] $Code) }
function __shlua_os_getenv { param($Name) [Environment]::GetEnvironmentVariable([string] $Name) }
function __shlua_os_remove { param($Path) Remove-Item -LiteralPath ([string] $Path); $true }
function __shlua_os_rename {
    param($Old, $New)
    Move-Item -LiteralPath ([string] $Old) -Destination ([string] $New)
    $true
}
function __shlua_os_time {
    $Epoch = [DateTime]::SpecifyKind([datetime] '1970-01-01', [DateTimeKind]::Utc)
    [Math]::Floor(((Get-Date).ToUniversalTime() - $Epoch).TotalSeconds)
}
function __shlua_os_tmpname { [IO.Path]::GetTempFileName() }]=]

return M
