# Stdlib shell-value quirks

- Bash command substitution loses mutation/state and strips trailing newlines; multi-return, seeded random, file-handle,
  and mutable table APIs must not be approximated through ordinary scalar helpers.
- Source arithmetic uses `awk` for decimals, while generated numeric-loop counters remain Bash integer arithmetic.
- PowerShell concatenation must cast both operands to string or a numeric left operand can coerce the right side.
- On Windows, quoted executables launched through `io.popen` need an outer command-line quote pair. Git Bash may exist
  beside `git.exe` even when `bash` is absent from `PATH`.
