local LuaType = require "Type"
local List = require "list"
local buffer = require "string.buffer"

--- A collection of characters of some kind as well as their location
--- in the input file.
---@class Token
--- The kind of this token.
---@field kind Token.Kind
--- Offset into the file where this Token starts.
---@field loc number
--- The length of this token.
---@field len number
--- Index of a Token preceeding this one that is not whitespace.
---@field prev_significant number?
--- Index of a Token following this one that is not whitespace.
---@field next_significant number?
local Token = LuaType.make()

Token.new = function(kind, start, stop)
  local o = {}
  o.kind = kind
  o.loc = start
  o.len = stop-start+1
  return setmetatable(o, Token)
end

Token.newVirtual = function(kind, raw)
  local o = {}
  o.raw = raw
  o.virtual = true
  return setmetatable(o, Token)
end

---@alias Token.Kind table<string, number>

---@type Token.Kind
Token.Kind = {}

Token.__tostring = function(self)
  local kindname
  for k,v in pairs(Token.Kind) do
    if v == self.kind then
      kindname = k
    end
  end

  if self.virtual then
    return "VToken("..kindname..","..self.raw..")"
  else
    return "Token("..kindname..","..self.loc.."+"..self.len..")"
  end
end

local tkcount = 0
local addTokenKind = function(id)
  Token.Kind[id] = { val = tkcount }
  tkcount = tkcount + 1
end

addTokenKind "Invalid"
addTokenKind "Eof"
addTokenKind "Whitespace"
addTokenKind "Comment"
addTokenKind "Identifier"
addTokenKind "Integer"
addTokenKind "Float"
addTokenKind "String"

Token.punc = List
{
  { "Colon", ":" },
  { "ThickArrow", "=>" },
  { "Equal", "=" },
  { "Semicolon", ";" },
  { "LParen", "(" },
  { "RParen", ")" },
  { "Comma", "," },
  { "Plus", "+" },
  { "Minus", "-" },
  { "LAngle", "<" },
  { "RAngle", ">" },
  { "BackTick", '`' },
  { "LBrace", "{" },
  { "RBrace", "}" },
  { "VerticalBar", "|" },
  { "Period", "." },
}

Token.punc:each(function(p)
  addTokenKind(p[1])
end)

Token.kw = List
{
  { "If", "if" },
  { "Else", "else" },
  { "Then", "then" },
  { "Struct", "struct" },
  { "True", "true" },
  { "False", "false" },
  { "And", "and" },
  { "Or", "or" },
  { "Is", "is" }
}

Token.kw:each(function(p)
  addTokenKind(p[1])
end)

local setProperty = function(prop, ...)
  List{...}:each(function(kind)
    kind[prop] = true
  end)
end

setProperty("is_literal",
  Token.Kind.Integer,
  Token.Kind.Float,
  Token.Kind.String,
  Token.Kind.True,
  Token.Kind.False)

return Token
