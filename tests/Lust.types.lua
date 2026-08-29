---@meta

--- Lust Testing Framework — EmmyLua Type Definitions
--- @module tests.Lust.types
--- @version 1.0.0
--- @license MIT
--- @author Björn Ritzl (@bjornbytes)
--- @copyright 2020-2024 Björn Ritzl
--- @see https://github.com/bjornbytes/lust
--- @see https://raw.githubusercontent.com/bjornbytes/lust/refs/heads/master/lust.lua
--- @see tests/Lust.lua for embedded runtime implementation in this project
---
--- This file provides EmmyLua annotations for the Lust testing framework globals.
--- These types are injected at runtime via `lust.injectGlobals()` in test files.
---
--- ## Original Library
--- Lust is a cutting-edge, zero-dependency Lua testing library by Björn Ritzl.
--- Source: https://github.com/bjornbytes/lust
--- License: MIT (see original repo for full license text)
---
--- ## Usage in This Project
--- ```lua
--- -- Test files automatically have globals injected via:
--- local lust = require("Lust")
--- lust.injectGlobals()
---
--- describe("My Suite", function()
---   it("passes", function()
---     expect(1 + 1).toBe(2)
---   end)
--- end)
---
--- lust.report() -- Call at end of test file
--- ```

---@class LustExpect
--- Matcher object returned by `expect(actual)` for assertions.
--- All matchers support chaining via `.not` modifier.
---
--- ## Example
--- ```lua
--- expect(42).toBe(42)
--- expect({a=1}).toEqual({a=1})
--- expect(true).toBeTruthy()
--- expect(false).toBeFalsy()
--- expect(function() error("fail") end).toThrow("fail")
--- expect(mockFn).toHaveBeenCalled()
--- expect(mockFn).toHaveBeenCalledWith(1, 2)
---
--- -- Inverted matchers
--- expect(1).not.toBe(2)
--- expect({}).not.toEqual({a=1})
--- ```
---@field toBe fun(self: LustExpect, expected: any) @ Strict equality (`===` equivalent). Use for primitives and reference identity.
---@field toEqual fun(self: LustExpect, expected: any) @ Deep equality for tables. Recursively compares keys/values.
---@field toBeTruthy fun(self: LustExpect) @ Asserts value is truthy (not `nil` or `false`).
---@field toBeFalsy fun(self: LustExpect) @ Asserts value is falsy (`nil` or `false`).
---@field toThrow fun(self: LustExpect, expectedError?: string) @ Asserts function throws. Optionally matches error message substring.
---@field toHaveBeenCalled fun(self: LustExpect) @ Asserts mock was called at least once.
---@field toHaveBeenCalledWith fun(self: LustExpect, ...: any) @ Asserts mock was called with specific arguments (deep equal).
---@field not LustExpect @ Inverted matchers. e.g. `expect(x).not.toBe(y)`

--- Creates an expectation for value assertions.
--- @param actual any Value to assert against
--- @return LustExpect Matcher object with assertion methods
--- @see LustExpect
function expect(actual) end

--- Defines a test suite (group of related tests).
--- @param name string Suite description
--- @param fn fun() Function containing nested `describe`, `it`, or `test` calls
--- @see it
--- @see test
---
--- ## Example
--- ```lua
--- describe("String utilities", function()
---   describe("trim()", function()
---     it("removes leading whitespace", function() ... end)
---     it("removes trailing whitespace", function() ... end)
---   end)
--- end)
--- ```
function describe(name, fn) end

--- Defines a single test case (alias for `test`).
--- @param name string Test description
--- @param fn fun() Test function containing assertions
--- @see describe
--- @see test
---
--- ## Example
--- ```lua
--- it("adds two numbers", function()
---   expect(add(2, 3)).toBe(5)
--- end)
--- ```
function it(name, fn) end

--- Defines a single test case (alias for `it`).
--- @param name string Test description
--- @param fun() Test function containing assertions
--- @see describe
--- @see it
function test(name, fn) end

---@class MockFunction
--- Callable mock object tracking invocations and arguments.
--- @field __isMock boolean Always `true` for type identification
--- @field calls any[][] Recorded calls as arrays of arguments. `mock.calls[1] == {arg1, arg2}`
--- @field mockClear fun(self: MockFunction) Clears call history
--- @field mockImplementation fun(self: MockFunction, fn: fun(...): any) Replaces implementation
--- @field mockReturnValue fun(self: MockFunction, val: any) Sets fixed return value
--- @overload fun(self: MockFunction, ...: any): any Callable — records call, delegates to impl

--- Creates a mock function with optional implementation.
--- @param implementation? fun(...): any Optional function to execute on call
--- @return MockFunction Callable mock with tracking methods
--- @see spyOn
---
--- ## Example
--- ```lua
--- local fn = mock(function(a, b) return a + b end)
--- fn(1, 2) -- returns 3
--- expect(fn).toHaveBeenCalledWith(1, 2)
---
--- -- Fixed return value
--- local const = mock()
--- const.mockReturnValue(42)
--- expect(const()).toBe(42)
--- ```
function mock(implementation) end

--- Spies on an existing table method, replacing it with a mock.
--- @param tbl table Table containing the method
--- @param methodName string Method name to spy on
--- @return MockFunction Mock wrapping original method (call `.mockRestore()` to restore)
--- @see mock
---
--- ## Example
--- ```lua
--- local obj = { greet = function(name) return "Hi " .. name end }
--- local spy = spyOn(obj, "greet")
---
--- obj.greet("Alice")
--- expect(spy).toHaveBeenCalledWith("Alice")
---
--- spy.mockRestore() -- Restore original
--- ```
function spyOn(tbl, methodName) end

--- Lust module table (also exposed globally as `lust` after `injectGlobals()`).
--- @class Lust
--- @field injectGlobals fun() Injects `describe`, `it`, `test`, `expect`, `spyOn`, `mock` into `_G`
--- @field describe fun(name: string, fn: fun())
--- @field it fun(name: string, fn: fun())
--- @field test fun(name: string, fn: fun())
--- @field expect fun(actual: any): LustExpect
--- @field spyOn fun(tbl: table, methodName: string): MockFunction
--- @field mock fun(implementation?: fun(...): any): MockFunction
--- @field report fun() Prints summary and exits with non-zero on failures
---
--- ## Example
--- ```lua
--- local lust = require("Lust")
--- lust.injectGlobals() -- or use globals directly in test files
---
--- describe("Suite", function()
---   it("passes", function()
---     expect(true).toBeTruthy()
---   end)
--- end)
---
--- lust.report() -- Call at end of test file
--- ```
lust = {}

--- Global Lust module instance (available after `lust.injectGlobals()`).
--- @type Lust
_G.lust = lust
