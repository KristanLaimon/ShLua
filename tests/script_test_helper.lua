package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local ShLua = require("shlua")

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
    local fullCommand = command .. " 2>&1"
    if package.config:sub(1, 1) == "\\" and command:sub(1, 1) == '"' then
        fullCommand = '"' .. fullCommand .. '"'
    end
    local pipe = assert(io.popen(fullCommand))
    local output = pipe:read("*a"):gsub("\r\n", "\n")
    local ok, _, code = pipe:close()
    return ok == true and (not code or code == 0), output
end

local function commandAvailable(command)
    local suffix = package.config:sub(1, 1) == "\\" and " >NUL 2>NUL" or " >/dev/null 2>&1"
    local ok = os.execute(command .. " --version" .. suffix)
    return ok == true or ok == 0
end

local function commandOnPath(command)
    local windows = package.config:sub(1, 1) == "\\"
    local probe = windows and ("where " .. command .. " >NUL 2>NUL") or ("command -v " .. command .. " >/dev/null 2>&1")
    local ok = os.execute(probe)
    return ok == true or ok == 0
end

local function fileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

local function findBash()
    if commandAvailable("bash") then
        return "bash"
    end
    if package.config:sub(1, 1) ~= "\\" then
        return nil
    end

    local pipe = io.popen("where git 2>NUL")
    if not pipe then
        return nil
    end
    local gitPath = pipe:read("*l")
    pipe:close()
    local gitRoot = gitPath and gitPath:match("^(.*)[/\\]cmd[/\\]git%.exe$")
    local bashPath = gitRoot and (gitRoot .. "\\bin\\bash.exe")
    if bashPath and fileExists(bashPath) then
        return bashPath
    end
    return nil
end

local function execute(path, target)
    if target == "bash" then
        local bash = findBash()
        if not bash then
            return nil, nil
        end
        return run(quote(bash) .. " " .. quote(path))
    end
    if commandOnPath("pwsh") then
        return run("pwsh -NoProfile -File " .. quote(path))
    elseif commandOnPath("powershell") then
        return run("powershell -NoProfile -ExecutionPolicy Bypass -File " .. quote(path))
    end
    return nil, nil
end

function M.compileAndRunTarget(name, source, target)
    local code = ShLua.transpile(source, target)
    local extension = target == "bash" and ".sh" or ".ps1"
    local path = "tests/scripts/" .. name .. extension
    writeFile(path, code)
    local ok, output = execute(path, target)
    return {
        code = code,
        executed = ok ~= nil,
        ok = ok,
        output = output,
        path = path,
    }
end

function M.compileAndRun(name, source)
    local outputs = ShLua.transpile(source, "all")
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
