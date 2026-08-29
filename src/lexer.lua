-- ============================================================================
-- Lexical Analyzer for the Lua 5.1 syntax used by Luash.
-- File: lexer.lua
-- Language: Lua (Output/Comments in English)
-- ============================================================================

local Lexer = {}
Lexer.__index = Lexer

-- Token Types definition
Lexer.TokenTypes = {
    KEYWORD = "KEYWORD",
    IDENTIFIER = "IDENTIFIER",
    NUMBER = "NUMBER",
    STRING = "STRING",
    OPERATOR = "OPERATOR",
    COMMENT = "COMMENT",
    EOF = "EOF",
}

-- Reserved Keywords in Lua
local KEYWORDS = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

-- Multi-character operators sorted by length (descending) to avoid partial matches
local MULTI_OPS = {
    "...",
    "..",
    "==",
    "~=",
    "<=",
    ">=",
}

-- Single-character operators/symbols
local SINGLE_OPS = {
    "+",
    "-",
    "*",
    "/",
    "%",
    "^",
    "#",
    "<",
    ">",
    "=",
    "(",
    ")",
    "{",
    "}",
    "[",
    "]",
    ";",
    ":",
    ",",
    ".",
}

--- Instantiates a new Lexer
-- @param input String containing the source code to tokenize
function Lexer.new(input)
    local self = setmetatable({}, Lexer)
    self.input = input
    self.pos = 1
    self.length = #input
    self.line = 1
    self.column = 1
    return self
end

-- Helper: Peek current character
function Lexer:peek(offset)
    offset = offset or 0
    local target = self.pos + offset
    if target > self.length then
        return nil
    end
    return self.input:sub(target, target)
end

-- Helper: Advance character position
function Lexer:advance(count)
    count = count or 1
    for i = 1, count do
        if self:peek() == "\n" then
            self.line = self.line + 1
            self.column = 1
        else
            self.column = self.column + 1
        end
        self.pos = self.pos + 1
    end
end

-- Skip Whitespace
function Lexer:skipWhitespace()
    while self.pos <= self.length do
        local ch = self:peek()
        if ch == " " or ch == "\t" or ch == "\r" or ch == "\n" then
            self:advance()
        else
            break
        end
    end
end

-- Check matching bracket level for long strings and long comments (e.g., `[=...=[`)
function Lexer:readLongBracketLevel()
    local level = 0
    self:advance() -- skip initial '['
    while self:peek() == "=" do
        level = level + 1
        self:advance()
    end
    if self:peek() == "[" then
        self:advance() -- skip closing '['
        return level
    end
    return nil
end

-- Lex Long String or Long Comment content given the opening bracket level
function Lexer:readLongString(level)
    local start_pos = self.pos
    while self.pos <= self.length do
        if self:peek() == "]" then
            self:advance()
            local current_level = 0
            while self:peek() == "=" do
                current_level = current_level + 1
                self:advance()
            end
            if current_level == level and self:peek() == "]" then
                self:advance()
                -- Extract inner contents excluding opening and closing delimiters
                return self.input:sub(start_pos, self.pos - level - 3)
            end
        else
            self:advance()
        end
    end
    error(string.format("Lexer Error: Unclosed long string/comment near line %d", self.line))
end

-- Read standard single or double-quoted string
function Lexer:readString(quote)
    self:advance() -- skip opening quote
    local value = {}

    while self.pos <= self.length do
        local ch = self:peek()
        if ch == "\\" then
            self:advance()
            local escaped = self:peek()
            local escapes = {
                ["a"] = "\a",
                ["b"] = "\b",
                ["f"] = "\f",
                ["n"] = "\n",
                ["r"] = "\r",
                ["t"] = "\t",
                ["v"] = "\v",
                ["\\"] = "\\",
                ['"'] = '"',
                ["'"] = "'",
            }
            if not escaped then
                error(string.format("Lexer Error: Unclosed string literal near line %d", self.line))
            end
            table.insert(value, escapes[escaped] or escaped)
            self:advance()
        elseif ch == quote then
            self:advance() -- skip closing quote
            return table.concat(value)
        elseif ch == "\n" then
            error(string.format("Lexer Error: Unescaped newline in string at line %d", self.line))
        else
            table.insert(value, ch)
            self:advance()
        end
    end
    error(string.format("Lexer Error: Unclosed string literal near line %d", self.line))
end

-- Read numeric literals (Integers, Floats, Hexadecimal, Scientific notation)
function Lexer:readNumber()
    local start_pos = self.pos

    -- Hexadecimal numbers
    if self:peek() == "0" and (self:peek(1) == "x" or self:peek(1) == "X") then
        self:advance(2)
        local digits = 0
        while self:peek() and self:peek():find("[0-9a-fA-F]") do
            digits = digits + 1
            self:advance()
        end
        if digits == 0 then
            error(string.format("Lexer Error: Malformed hexadecimal number at line %d", self.line))
        end
        return self.input:sub(start_pos, self.pos - 1)
    end

    -- Decimal numbers (integer, fraction, and optional exponent).
    if self:peek() == "." then
        self:advance()
        while self:peek() and self:peek():find("%d") do
            self:advance()
        end
    else
        while self:peek() and self:peek():find("%d") do
            self:advance()
        end
        if self:peek() == "." and self:peek(1) ~= "." then
            self:advance()
            while self:peek() and self:peek():find("%d") do
                self:advance()
            end
        end
    end

    if self:peek() == "e" or self:peek() == "E" then
        self:advance()
        if self:peek() == "+" or self:peek() == "-" then
            self:advance()
        end
        if not self:peek() or not self:peek():find("%d") then
            error(string.format("Lexer Error: Malformed exponent at line %d", self.line))
        end
        while self:peek() and self:peek():find("%d") do
            self:advance()
        end
    end

    return self.input:sub(start_pos, self.pos - 1)
end

-- Read Identifiers or Keywords
function Lexer:readIdentifier()
    local start_pos = self.pos
    while self.pos <= self.length do
        local ch = self:peek()
        if ch and ch:find("[%w_]") then
            self:advance()
        else
            break
        end
    end
    return self.input:sub(start_pos, self.pos - 1)
end

--- Retrieves the next token from the input stream
-- @return table Token table containing type, value, line, and column
function Lexer:nextToken()
    self:skipWhitespace()

    if self.pos > self.length then
        return { type = Lexer.TokenTypes.EOF, value = "EOF", line = self.line, column = self.column }
    end

    local start_line = self.line
    local start_col = self.column
    local ch = self:peek()

    -- 1. Comments & Long Comments
    if ch == "-" and self:peek(1) == "-" then
        self:advance(2)
        if self:peek() == "[" then
            local saved_pos = self.pos
            local level = self:readLongBracketLevel()
            if level then
                local comment_text = self:readLongString(level)
                return { type = Lexer.TokenTypes.COMMENT, value = comment_text, line = start_line, column = start_col }
            else
                self.pos = saved_pos -- Rollback if not a long comment delimiter
            end
        end

        -- Short comment (reads until end of line)
        local start_pos = self.pos
        while self.pos <= self.length and self:peek() ~= "\n" do
            self:advance()
        end
        local comment_text = self.input:sub(start_pos, self.pos - 1)
        return { type = Lexer.TokenTypes.COMMENT, value = comment_text, line = start_line, column = start_col }
    end

    -- 2. Strings (Short & Long)
    if ch == '"' or ch == "'" then
        local str = self:readString(ch)
        return { type = Lexer.TokenTypes.STRING, value = str, line = start_line, column = start_col }
    elseif ch == "[" then
        local saved_pos = self.pos
        local saved_col = self.column
        local saved_line = self.line
        local level = self:readLongBracketLevel()
        if level then
            local str = self:readLongString(level)
            return { type = Lexer.TokenTypes.STRING, value = str, line = start_line, column = start_col }
        end
        -- Reset if it's just a regular square bracket operator `[`
        self.pos = saved_pos
        self.column = saved_col
        self.line = saved_line
    end

    -- 3. Numbers (including numbers starting with `.`, e.g., `.5`)
    if ch:find("%d") or (ch == "." and self:peek(1) and self:peek(1):find("%d")) then
        local num = self:readNumber()
        return { type = Lexer.TokenTypes.NUMBER, value = num, line = start_line, column = start_col }
    end

    -- 4. Identifiers & Keywords
    if ch:find("[%a_]") then
        local id = self:readIdentifier()
        local token_type = KEYWORDS[id] and Lexer.TokenTypes.KEYWORD or Lexer.TokenTypes.IDENTIFIER
        return { type = token_type, value = id, line = start_line, column = start_col }
    end

    -- 5. Multi-character Operators
    for _, op in ipairs(MULTI_OPS) do
        local match = true
        for i = 1, #op do
            if self:peek(i - 1) ~= op:sub(i, i) then
                match = false
                break
            end
        end
        if match then
            self:advance(#op)
            return { type = Lexer.TokenTypes.OPERATOR, value = op, line = start_line, column = start_col }
        end
    end

    -- 6. Single-character Operators
    for _, op in ipairs(SINGLE_OPS) do
        if ch == op then
            self:advance(1)
            return { type = Lexer.TokenTypes.OPERATOR, value = op, line = start_line, column = start_col }
        end
    end

    error(string.format("Lexer Error: Unexpected character '%s' at line %d, column %d", ch, self.line, self.column))
end

--- Utility function to tokenize an entire script string into a table
function Lexer:tokenize()
    local tokens = {}
    while true do
        local token = self:nextToken()
        table.insert(tokens, token)
        if token.type == Lexer.TokenTypes.EOF then
            break
        end
    end
    return tokens
end

return Lexer
