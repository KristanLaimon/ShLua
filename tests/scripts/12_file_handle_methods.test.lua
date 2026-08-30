package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

local helper = require("script_test_helper")

local outputPath = "tests/scripts/12_file_handle_methods_runtime_output.txt"

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

describe("12 - File handle method script", function()
    it("transpiles annotated stdlib imports and file:write/file:close calls", function()
        local result = helper.compileAndRun(
            "12_file_handle_methods_runtime",
            [[local os = require("os")
local string = require("string")

---@param filePath string
---@param msgToPrint string
---@return {error?: nil | string}
function WriteToFile(filePath, msgToPrint)
    ---@type string
    local date = tostring(os.date())

    ---@type string
    local fullTxt = string.format("[%s]: %s", date, msgToPrint)

    local file = io.open(filePath, "w")
    if file == nil then
        return { error = "Couldn't open file..." }
    end

    local _, err = file:write(fullTxt)
    if err ~= nil then
        return { error = err }
    end

    file:close()
    return { error = nil }
end

---@type integer[]
local myCounter = {}
-- Keep this small: Bash table storage is filesystem-backed in the alpha runtime.
for i = 1, 3, 1 do
    table.insert(myCounter, i)
end

local myCounterAsString = ""
for _, v in ipairs(myCounter) do
    myCounterAsString = myCounterAsString .. tostring(v) .. "\n"
end

WriteToFile("tests/scripts/12_file_handle_methods_runtime_output.txt", myCounterAsString)]])

        for _, target in ipairs({ "bash", "ps1" }) do
            local targetResult = result[target]
            expect(targetResult.code:find("require", 1, true) ~= nil).toBeFalsy()
            expect(targetResult.code:find("__shlua_io_open", 1, true) ~= nil).toBeTruthy()
            expect(targetResult.code:find("__shlua_io_file_write", 1, true) ~= nil).toBeTruthy()
            if targetResult.executed then
                expect(targetResult.ok).toBeTruthy()
            end
        end

        if result.bash.executed or result.ps1.executed then
            local content = readFile(outputPath)
            expect(content:match("^%[.+%]: 1\n2\n3\n$") ~= nil).toBeTruthy()
            os.remove(outputPath)
        end
    end)
end)

lust.report()
