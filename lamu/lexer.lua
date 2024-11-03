local cmn = require "common"
local co = require "coroutine"
local Token = require "token"
local errh = require "errhandler"

--- Generates Tokens from some input text.
---@class lamu.Lexer
--- The buffer containing the text we are lexing.
---@field buffer string
--- Current offset into the buffer.
---@field offset number
--- List of Tokens we've found.
---@field tokens List
--- List of line offsets.
---@field lines List
local Lexer = cmn.LuaType.make()

Lexer.Done = {}

---@return lamu.Lexer
Lexer.new = function(filename, buffer)
  local o = {}
  o.buffer = buffer
  o.filename = filename
  local c = cmn.pco(Lexer.nextToken, errh)
  ---@return Token.Kind?
  o.nextToken = function(self, ...)
    if co.status(c) == "dead" then
      return Lexer.Done
    end
    local result = {co.resume(c, self, ...)}
    if not result[1] then
      error(result[2])
    end
    return unpack(result, 2)
  end
  o.offset = 1
  o.tokens = cmn.List{}
  return setmetatable(o, Lexer)
end

-- Try to match a pattern at the current position in the stream.
Lexer.pattern = function(self, pattern)
  return self.buffer:find("^"..pattern, self.offset)
end

-- Try to match a pattern and advance if we match. 
Lexer.checkPattern = function(self, pattern)
  local start, stop = self:pattern(pattern)
  if start then
    self.offset = stop + 1
    return start, stop
  end
end

-- Check if the given pattern occurs and advance if so. The 
-- matched text is returned.
Lexer.check = function(self, pattern)
  local start, stop = self:pattern(pattern)
  if start then
    self.offset = stop + 1
    return self.buffer:sub(start, stop)
  end
end

Lexer.pushToken = function(self, kind, start, stop)
  local t = Token.new(kind, start, stop)
  self.tokens:push(t)
  return t
end

Lexer.skipWhitespaceAndComments = function(self)
  while true do
    local start, stop = self:pattern "%s*"
    if start then
      if stop-start+1 > 0 then
        self:pushToken(Token.Kind.Whitespace, start, stop)
        self.offset = stop + 1
      end
    end

    local start, stop = self:pattern "//[^\n]*"
    if start then
      self.offset = stop + 1
    else
      break
    end
  end
end

local pattern_chars ={}

cmn.List
{
  "^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?"
}
:each(function(x) pattern_chars[string.byte(x)] = true end)

local escapePatternChars = function(s)
  local buf = cmn.buffer.new()

  cmn.List{s:byte(0,#s)}:each(function(byte)
    if pattern_chars[byte] then
      buf:put("%",string.char(byte))
    else
      buf:put(string.char(byte))
    end
  end)

  return buf:get()
end

---@return Token
Lexer.nextToken = function(self)
  local checkToken = function()
    if self.offset >= #self.buffer then
      return self:pushToken(Token.Kind.Eof, #self.buffer, #self.buffer)
    end

    for p in Token.punc:each() do
      local start, stop = self:checkPattern(escapePatternChars(p[2]))
      if start then
        return self:pushToken(Token.Kind[p[1]], start, stop)
      end
    end

    for k in Token.kw:each() do
      local start, stop = self:checkPattern(k[2])
      if start then
        return self:pushToken(Token.Kind[k[1]], start, stop)
      end
    end

    -- Check for numeric literals.
    local start, stop = self:checkPattern("%d+%.%d+")
    if start then
      return self:pushToken(Token.Kind.Float, start, stop)
    end

    local start, stop = self:checkPattern("%d+")
    if start then
      return self:pushToken(Token.Kind.Integer, start, stop)
    end

    -- Check for string literal.
    local start, stop = self:checkPattern('".-"')
    if start then
      return self:pushToken(Token.Kind.String, start+1,stop-1)
    end

    -- Check for an identifier.
    local start, stop = self:checkPattern("[%w_][%w_]*")
    if start then
      return self:pushToken(Token.Kind.Identifier, start, stop)
    end

    cmn.fatal("unhandled lex at ", self.offset)
  end

  while true do
    self:skipWhitespaceAndComments()

    local tok = checkToken()
    if tok.kind == Token.Kind.Eof then
      return tok
    else
      co.yield(tok)
    end
  end
end

Lexer.getRaw = function(self, tok)
  if tok.virtual then
    return tok.raw
  else
    return self.buffer:sub(tok.loc, tok.loc+tok.len-1)
  end
end

return Lexer
