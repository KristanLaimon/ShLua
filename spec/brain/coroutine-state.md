# Coroutine state

Shells cannot suspend a Lua stack. The alpha therefore compiles sequential yields into a small state machine, with
state stored on each created handle so two coroutines using the same worker do not interfere.
