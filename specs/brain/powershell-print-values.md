# PowerShell print values

`Write-Output` emits each positional argument as a separate pipeline value. Lua `print` needs one tab-separated line, so
generated PowerShell uses `__luash_print` to render `nil`, booleans, and numbers before writing one line.
