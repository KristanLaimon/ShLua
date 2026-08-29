package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local Luash = require("luash")

local M = {}

local function quote(path)
    return '"' .. path:gsub('"', '""') .. '"'
end

local function writeFile(path, content)
    local file, err = io.open(path, "wb")
    assert(file, "Script Test Error: cannot write " .. path .. ": " .. tostring(err))
    file:write(content)
    file:close()
end

local function run(command)
    local pipe = assert(io.popen(command .. " 2>&1"))
    local output = pipe:read("*a"):gsub("\r\n", "\n")
    local ok, _, code = pipe:close()
    return ok and (not code or code == 0), output
end

local function commandAvailable(command)
    local suffix = package.config:sub(1, 1) == "\\" and " >NUL 2>NUL" or " >/dev/null 2>&1"
    local ok = os.execute(command .. " --version" .. suffix)
    return ok == true or ok == 0
end

local function execute(path, target)
    if target == "bash" then
        if not commandAvailable("bash") then
            return nil, nil
        end
        return run("bash " .. quote(path))
    end
    if commandAvailable("pwsh") then
        return run("pwsh -NoProfile -File " .. quote(path))
    elseif commandAvailable("powershell") then
        return run("powershell -NoProfile -ExecutionPolicy Bypass -File " .. quote(path))
    end
    return nil, nil
end

function M.compileAndRun(name, source)
    local outputs = Luash.transpile(source, "all")
    local result = {}
    for _, target in ipairs({ "bash", "ps1" }) do
        local extension = target == "bash" and ".sh" or ".ps1"
        local path = "tests/scripts/" .. name .. extension
        writeFile(path, outputs[target])
        local ok, output = execute(path, target)
        result[target] = {
            code = outputs[target],
            executed = ok ~= nil,
            ok = ok,
            output = output,
            path = path,
        }
    end
    return result
end

function M.expectOutput(result, expected)
    for _, target in ipairs({ "bash", "ps1" }) do
        local targetResult = result[target]
        assert(not targetResult.code:find("require", 1, true), target .. " output must stay dependency-free")
        if targetResult.executed then
            assert(targetResult.ok, target .. " execution failed:\n" .. tostring(targetResult.output))
            assert(
                targetResult.output == expected,
                target
                    .. " output mismatch: expected "
                    .. string.format("%q", expected)
                    .. ", got "
                    .. string.format("%q", targetResult.output)
            )
        end
    end
end

return M
