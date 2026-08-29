-- lust.lua: A cutting-edge, zero-dependency Lua testing library
local lust = {}

-- ANSI Terminal Colors
local colors = {
	green = "\27[32m",
	red = "\27[31m",
	yellow = "\27[33m",
	blue = "\27[34m",
	gray = "\27[90m",
	reset = "\27[0m",
}

-- State Management
local state = {
	passes = 0,
	failures = 0,
	indent = 0,
	current_test = nil,
}

-- Utilities
local function printIndent()
	return string.rep("  ", state.indent)
end

local function deepEqual(t1, t2, ignore_mt)
	local ty1 = type(t1)
	local ty2 = type(t2)
	if ty1 ~= ty2 then
		return false
	end
	if ty1 ~= "table" then
		return t1 == t2
	end

	local mt = getmetatable(t1)
	if not ignore_mt and mt and mt.__eq then
		return t1 == t2
	end

	for k1, v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil or not deepEqual(v1, v2, ignore_mt) then
			return false
		end
	end
	for k2, v2 in pairs(t2) do
		local v1 = t1[k2]
		if v1 == nil then
			return false
		end
	end
	return true
end

-- ==========================================
-- Assertions (expect)
-- ==========================================
function lust.expect(actual)
	local function fail(message)
		error(message, 3)
	end

	local matchers = {}

	function matchers.toBe(expected)
		if actual ~= expected then
			fail(string.format("Expected %s to be %s", tostring(actual), tostring(expected)))
		end
	end

	function matchers.toEqual(expected)
		if not deepEqual(actual, expected) then
			fail("Expected objects to be deeply equal")
		end
	end

	function matchers.toBeTruthy()
		if not actual then
			fail(string.format("Expected %s to be truthy", tostring(actual)))
		end
	end

	function matchers.toBeFalsy()
		if actual then
			fail(string.format("Expected %s to be falsy", tostring(actual)))
		end
	end

	function matchers.toThrow(expectedError)
		if type(actual) ~= "function" then
			fail("expect().toThrow requires a function")
		end
		local ok, err = pcall(actual)
		if ok then
			fail("Expected function to throw an error, but it did not")
		end
		if expectedError and not string.find(tostring(err), expectedError, 1, true) then
			fail(string.format("Expected error containing '%s', got '%s'", expectedError, tostring(err)))
		end
	end

	function matchers.toHaveBeenCalled()
		if type(actual) ~= "table" or not actual.__isMock then
			fail("expect().toHaveBeenCalled requires a mock function")
		end
		if #actual.calls == 0 then
			fail("Expected mock to have been called at least once")
		end
	end

	function matchers.toHaveBeenCalledWith(...)
		if type(actual) ~= "table" or not actual.__isMock then
			fail("expect().toHaveBeenCalledWith requires a mock function")
		end
		local expectedArgs = { ... }
		for _, callArgs in ipairs(actual.calls) do
			if deepEqual(callArgs, expectedArgs) then
				return true
			end
		end
		fail("Expected mock to have been called with specific arguments, but it was not")
	end

	-- Modifier: .not
	matchers["not"] = {}
	for name, func in pairs(matchers) do
		if name ~= "not" then
			matchers["not"][name] = function(...)
				local ok, _ = pcall(func, ...)
				if ok then
					fail("Expected " .. name .. " to fail, but it passed (inverted by .not)")
				end
			end
		end
	end

	return matchers
end

-- ==========================================
-- Mocking & Spying
-- ==========================================
function lust.mock(implementation)
	local m = {
		__isMock = true,
		calls = {},
		mockClear = function(self)
			self.calls = {}
		end,
		mockImplementation = function(self, fn)
			self.impl = fn
		end,
		mockReturnValue = function(self, val)
			self.impl = function()
				return val
			end
		end,
		impl = implementation or function() end,
	}

	local mt = {
		__call = function(self, ...)
			table.insert(self.calls, { ... })
			return self.impl(...)
		end,
	}
	setmetatable(m, mt)
	return m
end

function lust.spyOn(tbl, methodName)
	local original = tbl[methodName]
	if type(original) ~= "function" then
		error(string.format("Cannot spy on non-function '%s'", methodName), 2)
	end

	local m = lust.mock(original)
	m.mockRestore = function()
		tbl[methodName] = original
	end
	tbl[methodName] = m
	return m
end

-- ==========================================
-- Test Runner (describe, it, test)
-- ==========================================
function lust.describe(name, fn)
	print(printIndent() .. name)
	state.indent = state.indent + 1
	fn()
	state.indent = state.indent - 1
end

local function runTest(name, fn)
	io.write(printIndent() .. colors.gray .. "• " .. colors.reset .. name .. " ")

	local ok, err = pcall(fn)

	if ok then
		state.passes = state.passes + 1
		print(
			"\r" .. printIndent() .. colors.green .. "✓" .. colors.reset .. " " .. colors.gray .. name .. colors.reset
		)
	else
		state.failures = state.failures + 1
		print("\r" .. printIndent() .. colors.red .. "✕" .. colors.reset .. " " .. colors.red .. name .. colors.reset)

		-- Parse stack trace to format nicely
		local cleanErr = tostring(err)
		print(printIndent() .. "  " .. colors.red .. cleanErr .. colors.reset)
	end
end

lust.it = runTest
lust.test = runTest

-- ==========================================
-- Summary / Runner Execution
-- ==========================================
function lust.report()
	print("\n" .. string.rep("-", 40))
	print(colors.green .. state.passes .. " passing" .. colors.reset)
	if state.failures > 0 then
		print(colors.red .. state.failures .. " failing" .. colors.reset)
		os.exit(1)
	end
end

-- Inject globals automatically if requested
function lust.injectGlobals()
	_G.describe = lust.describe
	_G.it = lust.it
	_G.test = lust.test
	_G.expect = lust.expect
	_G.spyOn = lust.spyOn
	_G.mock = lust.mock
end

return lust
