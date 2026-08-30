package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local ShLua = require("shlua")

local function quote(path)
    return '"' .. path:gsub('"', '""') .. '"'
end

local function writeTemporary(content, target)
    local generatedName = os.tmpname():match("[^/\\]+$") or "shlua-integration"
    local extension = target == "bash" and ".sh" or ".ps1"
    generatedName = generatedName:gsub("%.*$", "") .. extension
    local path = "tests/" .. generatedName
    local file = assert(io.open(path, "wb"))
    file:write(content)
    file:close()
    return path
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
    return bashPath and fileExists(bashPath) and bashPath or nil
end

local function executeTarget(source, target)
    local path = writeTemporary(ShLua.transpile(source, target), target)
    local command
    if target == "bash" then
        local bash = assert(findBash(), "Bash is required for Bash integration tests")
        command = quote(bash) .. " " .. quote(path)
    elseif commandOnPath("pwsh") then
        command = "pwsh -NoProfile -File " .. quote(path)
    else
        command = "powershell -NoProfile -ExecutionPolicy Bypass -File " .. quote(path)
    end
    local ok, output = run(command)
    os.remove(path)
    return ok, output
end

local BASIC_SOURCE = [[
local function add(a, b)
    return a + b
end
local result = add(2, 3)
if result == 5 then
    print("sum=" .. result)
end
]]

local COROUTINE_SOURCE = [[
local function worker()
    coroutine.yield("one")
    coroutine.yield("two")
    return "done"
end
local co = coroutine.create(worker)
local ok, value = coroutine.resume(co)
print(value)
ok, value = coroutine.resume(co)
print(value)
ok, value = coroutine.resume(co)
print(value)
ok, value = coroutine.resume(co)
print(value)
]]

local PHASE_THREE_SOURCE = [[
local value = "outer"
if true then
    local value = "inner"
    print(value)
end

local total = 0
for i = 1, 5 do
    if i == 4 then
        break
    end
    total = total + i
end
while total < 8 do
    total = total + 1
end
repeat
    local finished = total >= 10
    total = total + 1
until finished

local function make(prefix)
    return function(suffix)
        return prefix .. suffix
    end
end
local greet = make("hello ")
local function make_named(prefix)
    local function join(suffix)
        return prefix .. suffix
    end
    return join
end
local named_greet = make_named("named ")
local function factorial(number)
    if number <= 1 then
        return 1
    end
    return number * factorial(number - 1)
end
print(value)
print(total)
print(greet("Lua"))
print(named_greet("closure"))
print(factorial(5))
]]

describe("Generated Script Integration", function()
    it("executes complex Bash output", function()
        local ok, output = executeTarget(BASIC_SOURCE, "bash")
        if not ok then
            error(output)
        end
        expect(output).toBe("sum=5\n")
    end)

    it("executes Bash coroutine transitions", function()
        local ok, output = executeTarget(COROUTINE_SOURCE, "bash")
        if not ok then
            error(output)
        end
        expect(output).toBe("one\ntwo\ndone\ncannot resume dead coroutine\n")
    end)

    it("executes complex PowerShell output when PowerShell is installed", function()
        if not commandOnPath("powershell") and not commandOnPath("pwsh") then
            return
        end
        local ok, output = executeTarget(BASIC_SOURCE, "ps1")
        if not ok then
            error(output)
        end
        expect(output).toBe("sum=5\n")
    end)

    it("executes PowerShell coroutine transitions when PowerShell is installed", function()
        if not commandOnPath("powershell") and not commandOnPath("pwsh") then
            return
        end
        local ok, output = executeTarget(COROUTINE_SOURCE, "ps1")
        if not ok then
            error(output)
        end
        expect(output).toBe("one\ntwo\ndone\ncannot resume dead coroutine\n")
    end)

    it("executes Phase 1-3 Bash output", function()
        local ok, output = executeTarget(PHASE_THREE_SOURCE, "bash")
        if not ok then
            error(output)
        end
        expect(output).toBe("inner\nouter\n11\nhello Lua\nnamed closure\n120\n")
    end)

    it("executes Phase 1-3 PowerShell output when PowerShell is installed", function()
        if not commandOnPath("powershell") and not commandOnPath("pwsh") then
            return
        end
        local ok, output = executeTarget(PHASE_THREE_SOURCE, "ps1")
        if not ok then
            error(output)
        end
        expect(output).toBe("inner\nouter\n11\nhello Lua\nnamed closure\n120\n")
    end)
end)

lust.report()
