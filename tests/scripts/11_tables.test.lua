package.path = "src/?.lua;src/?/init.lua;tests/?.lua;" .. package.path

local helper = require("script_test_helper")

local source = [[
local values = { 3, 1, 2 }
local alias = values
alias[2] = 4
print(values[2])
print(type(values) .. "\t" .. #values)

table.insert(values, 2, 1)
local removed = table.remove(values, 3)
table.sort(values)
print(table.concat(values, ",") .. "\t" .. removed)

local function descending(left, right)
    return left > right
end

table.sort(values, descending)
print(table.concat(values, ":"))

local keyed = { name = "Luash", [10] = "number-key", ["10"] = "string-key", false }
local stringKey = "10"
keyed.extra = "field"
keyed.name = nil
print(
    keyed[10]
        .. "\t"
        .. keyed[stringKey]
        .. "\t"
        .. keyed.extra
        .. "\t"
        .. (keyed.name or "nil")
        .. "\t"
        .. table.maxn(keyed)
)

local nested = { inner = { "nested" } }
print(nested.inner[1])

local function makeTable(value)
    return { value }
end

local returned = makeTable("returned")
local returnedAlias = returned
returnedAlias[1] = "changed"
print(returned[1])

local sequence = ""
for index, value in ipairs(values) do
    sequence = sequence .. index .. "=" .. value .. ";"
end
print(sequence)

local seen = 0
for key, value in pairs(keyed) do
    seen = seen + 1
end
print(seen)
]]

local result = helper.compileAndRun("11_tables", source)
helper.expectOutput(
    result,
    table.concat({
        "4",
        "table\t3",
        "1,2,3\t4",
        "3:2:1",
        "number-key\tstring-key\tfield\tnil\t10",
        "nested",
        "changed",
        "1=3;2=2;3=1;",
        "4",
        "",
    }, "\n")
)
