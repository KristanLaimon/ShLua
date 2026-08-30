local Luash = require("luash")
local helper = require("script_test_helper")

local M = {}

local function expectHelpers(target, source, helpers)
    local code = Luash.transpile(source, target)
    for _, name in ipairs(helpers) do
        expect(code:find(name, 1, true) ~= nil).toBeTruthy()
    end
end

local function stableBehaviorSource()
    return [[print(tonumber("42"), tonumber("ff", 16), tostring(false), tostring(nil))
print(type(12), type("Lua"), type(true), type(nil))
io.write("left", ":", 42)
io.flush()
print("right")
print(math.abs(-4.5), math.ceil(-3.8), math.floor(-3.2), math.max(-2, 7, 4), math.min(-2, 7, 4))
print(math.sqrt(81), math.pow(2, 5), math.fmod(-7, 3))
print(math.pi)
print(os.difftime(10, 3))
print(type(os.time()), type(os.clock()))
print(string.upper("Lua"), string.lower("SHELL"), string.len("hello"), string.rep("ab", 3))
print(string.reverse("abc"), string.sub("abcdef", -4, -2), string.byte("A"), string.char(65, 66))
print(string.find("hello world", "world", 1, true))
print(string.format("%s %.2f", "value", 3.14159))
local values = { 3, 1, 2 }
table.insert(values, 2, 4)
local removed = table.remove(values, 3)
table.sort(values)
print(table.concat(values, ","), removed, table.maxn(values))]]
end

local function expectedBehavior(pi)
    return "42\t255\tfalse\tnil\n"
        .. "number\tstring\tboolean\tnil\n"
        .. "left:42right\n"
        .. "4.5\t-3\t-4\t7\t-2\n"
        .. "9\t32\t-1\n"
        .. pi
        .. "\n7\nnumber\tnumber\n"
        .. "LUA\tshell\t5\tababab\n"
        .. "cba\tcde\t65\tAB\n"
        .. "7\nvalue 3.14\n"
        .. "2,3,4\t1\t3\n"
end

function M.run(target, name, pi)
    local result = helper.compileAndRunTarget(name, stableBehaviorSource(), target)

    describe(target .. " standard-library conformance", function()
        it("executes stable Lua-like behavior across every supported library", function()
            if result.executed then
                expect(result.ok).toBeTruthy()
                expect(result.output).toBe(expectedBehavior(pi))
            end
        end)

        it("selects all supported base and io helpers", function()
            expectHelpers(
                target,
                [[print(tonumber("1"), tostring(1), type(1))
io.flush()
io.write("x")
local value = io.read()]],
                {
                    "__luash_tonumber",
                    "__luash_tostring",
                    "__luash_type",
                    "__luash_io_flush",
                    "__luash_io_write",
                    "__luash_io_read",
                }
            )
        end)

        it("selects every supported math helper", function()
            expectHelpers(
                target,
                [[print(
    math.abs(1), math.acos(1), math.asin(1), math.atan(1), math.atan2(1, 1), math.ceil(1), math.cos(1),
    math.cosh(1), math.deg(1), math.exp(1), math.floor(1), math.fmod(1, 1), math.ldexp(1, 1), math.log(1),
    math.log10(1), math.max(1, 2), math.min(1, 2), math.pow(1, 1), math.rad(1), math.sin(1), math.sinh(1),
    math.sqrt(1), math.tan(1), math.tanh(1)
)]],
                {
                    "__luash_math_abs",
                    "__luash_math_acos",
                    "__luash_math_asin",
                    "__luash_math_atan",
                    "__luash_math_atan2",
                    "__luash_math_ceil",
                    "__luash_math_cos",
                    "__luash_math_cosh",
                    "__luash_math_deg",
                    "__luash_math_exp",
                    "__luash_math_floor",
                    "__luash_math_fmod",
                    "__luash_math_ldexp",
                    "__luash_math_log",
                    "__luash_math_log10",
                    "__luash_math_max",
                    "__luash_math_min",
                    "__luash_math_pow",
                    "__luash_math_rad",
                    "__luash_math_sin",
                    "__luash_math_sinh",
                    "__luash_math_sqrt",
                    "__luash_math_tan",
                    "__luash_math_tanh",
                }
            )
        end)

        it("selects every supported os helper without executing unsafe operations", function()
            expectHelpers(
                target,
                [[print(
    os.clock(), os.date(), os.difftime(1, 0), os.execute(""), os.getenv("PATH"), os.time(), os.tmpname()
)
os.remove("old")
os.rename("old", "new")
os.exit(0)]],
                {
                    "__luash_os_clock",
                    "__luash_os_date",
                    "__luash_os_difftime",
                    "__luash_os_execute",
                    "__luash_os_getenv",
                    "__luash_os_remove",
                    "__luash_os_rename",
                    "__luash_os_time",
                    "__luash_os_tmpname",
                    "__luash_os_exit",
                }
            )
        end)

        it("selects every supported string helper", function()
            expectHelpers(
                target,
                [[print(
    string.byte("a"), string.char(65), string.find("a", "a", 1, true), string.format("%s", "a"), string.len("a"),
    string.lower("A"), string.rep("a", 1), string.reverse("a"), string.sub("a", 1), string.upper("a")
)]],
                {
                    "__luash_string_byte",
                    "__luash_string_char",
                    "__luash_string_find",
                    "__luash_string_format",
                    "__luash_string_len",
                    "__luash_string_lower",
                    "__luash_string_rep",
                    "__luash_string_reverse",
                    "__luash_string_sub",
                    "__luash_string_upper",
                }
            )
        end)

        it("selects every supported table helper", function()
            expectHelpers(
                target,
                [[local values = { 2, 1 }
table.insert(values, 1)
table.remove(values, 1)
table.sort(values)
print(table.concat(values, ","), table.maxn(values))]],
                {
                    "__luash_table_insert",
                    "__luash_table_remove",
                    "__luash_table_sort",
                    "__luash_table_concat",
                    "__luash_table_maxn",
                }
            )
        end)

        it("rejects APIs that cannot preserve their Lua multi-value or pattern semantics", function()
            expect(function()
                helper.compileAndRunTarget(name, [[print(string.gmatch("abc", "."))]], target)
            end).toThrow("requires Lua pattern matching")
            expect(function()
                helper.compileAndRunTarget(name, [[print(math.modf(1.5))]], target)
            end).toThrow("returns multiple values")
        end)
    end)
end

return M
