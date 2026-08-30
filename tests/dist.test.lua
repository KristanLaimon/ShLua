package.path = "tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

package.loaded.shlua = nil
package.path = "dist/?.lua"
local ShLua = require("shlua")

local function quote(path)
    return '"' .. path:gsub('"', '""') .. '"'
end

local function readBinary(path)
    local file = assert(io.open(path, "rb"))
    local content = file:read("*a")
    file:close()
    return content
end

local function readLittleEndian(content, startIndex, byteCount)
    local value = 0
    local factor = 1
    for index = 0, byteCount - 1 do
        value = value + string.byte(content, startIndex + index) * factor
        factor = factor * 256
    end
    return value
end

describe("Single-file Distribution", function()
    it("creates valid SRLua packages for Windows and Linux", function()
        local targets = {
            { path = "dist/shlua.exe", magic = "MZ", footerLongBytes = 4 },
            { path = "dist/shlua", magic = "\127ELF", footerLongBytes = 8 },
        }

        for _, target in ipairs(targets) do
            local content = readBinary(target.path)
            local footerLength = 8 + (target.footerLongBytes * 2)
            local footerStart = #content - footerLength + 1
            local runtimeSize = readLittleEndian(content, footerStart + 8, target.footerLongBytes)
            local payloadSize =
                readLittleEndian(content, footerStart + 8 + target.footerLongBytes, target.footerLongBytes)

            expect(content:sub(1, #target.magic)).toBe(target.magic)
            expect(content:sub(footerStart, footerStart + 7)).toBe("%%glue:L")
            expect(runtimeSize + payloadSize + footerLength).toBe(#content)
            expect(payloadSize > 0).toBeTruthy()
        end
    end)

    it("loads without source modules on package.path", function()
        expect(ShLua.VERSION).toBe("0.1.0-alpha")
        local code = ShLua.transpile("local answer = 6 * 7", "bash")
        expect(code:find("answer=\"$(__shlua_arithmetic 6 '*' 7)\"", 1, true) ~= nil).toBeTruthy()
    end)

    it("returns both targets from the reusable API", function()
        local outputs = ShLua.compile("print('hello')", "all")
        expect(type(outputs.bash)).toBe("string")
        expect(type(outputs.ps1)).toBe("string")
    end)

    it("runs as a standalone compiler", function()
        local tempRoot = os.getenv("TEMP") or os.getenv("TMPDIR") or "."
        local separator = package.config:sub(1, 1)
        local name = (os.tmpname():match("[^/\\]+$") or "shluadist"):gsub("[^%w_]", "")
        local inputPath = tempRoot .. separator .. name .. ".lua"
        local outputBase = tempRoot .. separator .. name .. "_output"
        local outputPath = outputBase .. ".sh"
        local input = assert(io.open(inputPath, "wb"))
        input:write("print('from dist')")
        input:close()

        local command = "lua dist/shlua.lua -i " .. quote(inputPath) .. " -o " .. quote(outputBase) .. " -t bash"
        local ok = os.execute(command)
        local output = io.open(outputPath, "rb")
        local code = output and output:read("*a") or ""
        if output then
            output:close()
        end
        os.remove(inputPath)
        os.remove(outputPath)

        expect(ok == true or ok == 0).toBeTruthy()
        expect(code:find("from dist", 1, true) ~= nil).toBeTruthy()
    end)

    if package.config:sub(1, 1) == "\\" then
        it("runs the Windows SRLua executable", function()
            local tempRoot = os.getenv("TEMP") or "."
            local separator = package.config:sub(1, 1)
            local name = (os.tmpname():match("[^/\\]+$") or "shluaexec"):gsub("[^%w_]", "")
            local inputPath = tempRoot .. separator .. name .. ".lua"
            local outputBase = tempRoot .. separator .. name .. "_output"
            local outputPath = outputBase .. ".sh"
            local input = assert(io.open(inputPath, "wb"))
            input:write("print('from executable')")
            input:close()

            local command = "dist\\shlua.exe -i " .. quote(inputPath) .. " -o " .. quote(outputBase) .. " -t bash"
            local ok = os.execute(command)
            local output = io.open(outputPath, "rb")
            local code = output and output:read("*a") or ""
            if output then
                output:close()
            end
            os.remove(inputPath)
            os.remove(outputPath)

            expect(ok == true or ok == 0).toBeTruthy()
            expect(code:find("from executable", 1, true) ~= nil).toBeTruthy()
        end)
    end
end)

lust.report()
