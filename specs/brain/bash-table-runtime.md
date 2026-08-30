# Bash table test size

The Bash table runtime persists entries in temporary filesystem directories. Keep end-to-end table fixtures small when
they are intended to exercise unrelated language features; large insertion loops make the test suite disproportionately
slow.
