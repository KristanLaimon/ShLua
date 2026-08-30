---@diagnostic disable: lowercase-global, undefined-global
-- luacheck configuration for ShLua
-- https://github.com/mpeterv/luacheck

std = "lua51"

-- Global variables allowed (Lust testing framework globals)
globals = {
    "describe",
    "it",
    "test",
    "expect",
    "spyOn",
    "mock",
    "_G",
    "arg",
}

-- Files to ignore
exclude_files = {
    "tests/Lust.lua",
}

-- Allow unused arguments in callbacks (common in Lust tests)
ignore = {
    "212", -- Unused argument
    "213", -- Unused loop variable
}

-- Per-file overrides
files["tests/**/*.test.lua"] = {
    globals = {
        "describe",
        "it",
        "test",
        "expect",
        "spyOn",
        "mock",
        "lust",
    },
}

files["src/**/*.lua"] = {
    -- Allow module pattern
    allow_defined = true,
    allow_defined_top = true,
}

-- Max line length (matches stylua)
max_line_length = 120
