local M = {}

---Extracts named helper definitions from a standard-library template.
---@param source string Target runtime template.
---@param target "bash"|"powershell" Target template syntax.
---@return table<string, string> fragments Source fragment by helper name.
---@return table[] ordered Helpers in source order.
local function helperFragments(source, target)
    local pattern
    if target == "bash" then
        pattern = "()\n(__shlua_[%w_]+)%(%)[ \t]*{"
    else
        pattern = "()\nfunction[ \t]+(__shlua_[%w_]+)[ \t]*{"
    end

    local padded = "\n" .. source
    local starts = {}
    for position, name in padded:gmatch(pattern) do
        table.insert(starts, { name = name, position = position + 1 })
    end

    local fragments = {}
    for index, entry in ipairs(starts) do
        local nextEntry = starts[index + 1]
        local last = nextEntry and nextEntry.position - 2 or #padded
        fragments[entry.name] = padded:sub(entry.position, last):gsub("%s+$", "")
    end
    return fragments, starts
end

---Renders only the standard-library helpers required by a target program.
---@param library table Standard-library metadata and source template.
---@param requirements table Required calls and helper names.
---@param target "bash"|"powershell" Target runtime syntax.
---@return string source Selected helper source.
function M.render(library, requirements, target)
    local required = {}
    for call in pairs(requirements.calls or {}) do
        local helper = library.functions[call]
        if helper then
            required[helper] = true
        end
        for _, extra in ipairs((library.callHelpers or {})[call] or {}) do
            required[extra] = true
        end
    end
    for helper in pairs(requirements.helpers or {}) do
        required[helper] = true
    end

    local function includeDependencies(helper)
        if required[helper] == "visiting" then
            error("Stdlib selector error: cyclic helper dependency for " .. helper)
        elseif required[helper] then
            required[helper] = "visiting"
            for _, dependency in ipairs((library.dependencies or {})[helper] or {}) do
                if not required[dependency] then
                    required[dependency] = true
                end
                includeDependencies(dependency)
            end
            required[helper] = true
        end
    end
    local roots = {}
    for helper in pairs(required) do
        table.insert(roots, helper)
    end
    for _, helper in ipairs(roots) do
        includeDependencies(helper)
    end

    local fragments, ordered = helperFragments(library.source, target)
    local output = {}
    local needsPrefix = next(required) and library.prefix
    if library.prefixHelpers then
        needsPrefix = false
        for helper in pairs(library.prefixHelpers) do
            if required[helper] then
                needsPrefix = true
                break
            end
        end
    end
    if needsPrefix then
        table.insert(output, library.prefix)
    end
    for _, entry in ipairs(ordered) do
        if required[entry.name] then
            assert(fragments[entry.name], "Stdlib selector error: missing helper " .. entry.name)
            table.insert(output, fragments[entry.name])
        end
    end
    return table.concat(output, "\n\n")
end

return M
