# Closure capture encoding

Bash 3.2 has no associative arrays, so Phase 3 closure values encode read-only captures with an internal field
separator and dispatch through `__shlua_call`. Reject writes to captured bindings; values containing the separator are
outside the portable subset. PowerShell uses a hashtable environment.
