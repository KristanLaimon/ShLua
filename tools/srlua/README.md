# Vendored SRLua runtimes

`run_build.lua` packages the standalone ShLua bundle with these SRLua 5.1.5 runtimes:

- `windows/srlua515.exe`: Windows x64
- `linux/srlua515`: Linux x64

They implement the self-running Lua program format from [LuaDist/srlua](https://github.com/LuaDist/srlua), whose source
is public domain. SRLua's tiny `glue` program concatenates the runtime and script, then appends its `%%glue:L` footer.
The build script performs that documented operation directly, which permits producing both target artifacts from either
host platform without a C toolchain, LuaInstaller installation, clone, or network connection.

The runtime checksums are:

| Runtime | SHA-256 |
| --- | --- |
| `windows/srlua515.exe` | `3436D705685C8286786E515817B8257E01A4D998F82C92C2D9E770B2811BE22D` |
| `linux/srlua515` | `62FC472113CC79720DAF4ECA23E885CF689CC8B812168AE132CC91D369DEAA2F` |
