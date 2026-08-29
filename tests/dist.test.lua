package.path = "tests/?.lua;" .. package.path

local lust = require("Lust")
lust.injectGlobals()

package.loaded.luash = nil
package.path = "dist/?.lua"
local Luash = require("luash")

local function quote(path)
    return '"' .. path:gsub('"', '""') .. '"'
end

describe("Single-file Distribution", function()
    it("loads without source modules on package.path", function()
        expect(Luash.VERSION).toBe("0.1.0-alpha")
        local code = Luash.transpile("local answer = 6 * 7", "bash")
        expect(code:find("answer=$(( (6 * 7) ))", 1, true) ~= nil).toBeTruthy()
    end)

    it("returns both targets from the reusable API", function()
        local outputs = Luash.compile("print('hello')", "all")
        expect(type(outputs.bash)).toBe("string")
        expect(type(outputs.ps1)).toBe("string")
    end)

    it("runs as a standalone compiler", function()
        local tempRoot = os.getenv("TEMP") or os.getenv("TMPDIR") or "."
        local separator = package.config:sub(1, 1)
        local name = (os.tmpname():match("[^/\\]+$") or "luashdist"):gsub("[^%w_]", "")
        local inputPath = tempRoot .. separator .. name .. ".lua"
        local outputBase = tempRoot .. separator .. name .. "_output"
        local outputPath = outputBase .. ".sh"
        local input = assert(io.open(inputPath, "wb"))
        input:write("print('from dist')")
        input:close()

        local command = "lua dist/luash.lua -i " .. quote(inputPath) .. " -o " .. quote(outputBase) .. " -t bash"
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
end)

lust.report()
