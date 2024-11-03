---
--- Type system.
---

local cmn = require "common"
local ast = require "ast"
local util = require "util"
local diag = require "diag"

local Type = cmn.LuaType.make()
Type.traits = {}

local TypeTrait = cmn.LuaType.make()

Type.addTrait = function(self, trait)
  self.traits[trait] = true
  if trait.implies then
    trait.implies:each(function(implied)
      self:addTrait(implied)
    end)
  end
end

Type.derive = function(self, ...)
  local o = setmetatable({}, { __index = self })
  o.__index = o
  o.traits = {}
  cmn.List{...}:each(function(trait)
    o:addTrait(trait)
  end)
  for trait in pairs(self.traits) do
    o:addTrait(trait)
  end
  return o
end

Type.getSize = function(self)
  return 0
end

Type.getTypeName = function(self)
  return "*getTypeName unhandled*"
end

TypeTrait.new = function(o)
  if o.implies then
    o.implies = cmn.List(o.implies)
  end
  return setmetatable(o, TypeTrait)
end

Type.is = function(self, T)
  if T:is(TypeTrait) then
    return self.traits[T]
  else
    return cmn.LuaType.is(self, T)
  end
end

local type = {}

type.Type = Type

type.builtin = {}

type.Sized = TypeTrait{}

type.Named = TypeTrait{}

type.Scalar = Type:derive(type.Sized)

type.Integral = TypeTrait{}
type.Floating = TypeTrait{}
type.Signed = TypeTrait{}
type.Unsigned = TypeTrait{}

type.Scalar.getSize = function(self)
  return self.size
end

type.Scalar.Kind = cmn.enum(cmn.Twine.new
  "u8"
  "u16"
  "u32"
  "u64"
  "s8"
  "s16"
  "s32"
  "s64"
  "f32"
  "f64")

type.Scalar.decideBinaryOpType = function(lhs, rhs)
  if lhs.kind.val > rhs.kind.val then
    return true
  else
    return false
  end
end

local defBuiltin = function(name, size, ...)
  local o = type.Scalar:derive(type.Named, ...)
  o.name = name
  o.size = size
  o.kind = type.Scalar.Kind[name]
  o.getTypeName = function(self)
    return self.name
  end
  type.builtin[name] = o
end

defBuiltin( "b8", 1, type.Integral, type.Unsigned)
defBuiltin( "u8", 1, type.Integral, type.Unsigned)
defBuiltin("u16", 2, type.Integral, type.Unsigned)
defBuiltin("u32", 4, type.Integral, type.Unsigned)
defBuiltin("u64", 8, type.Integral, type.Unsigned)
defBuiltin( "s8", 1, type.Integral, type.Signed)
defBuiltin("s16", 2, type.Integral, type.Signed)
defBuiltin("s32", 4, type.Integral, type.Signed)
defBuiltin("s64", 8, type.Integral, type.Signed)
defBuiltin("f32", 4, type.Floating, type.Signed)
defBuiltin("f64", 8, type.Floating, type.Signed)

type.Scalar.castTo = function(self, to)
  if not to:is(type.Scalar) then
    return diag.attempt_to_cast_scalar_to_nonscalar
  end
  return true
end

local Pointer = type.builtin.u64:derive()
type.Pointer = Pointer

Pointer.size = 8

Pointer.new = function(subtype)
  local o = {}
  o.subtype = subtype
  return setmetatable(o, Pointer)
end

local Record = Type:derive(type.Sized)
type.Record = Record

Record.new = function(decl, size, fields)
  local o = {}
  if not decl:is(ast.StructTuple) then
    cmn.fatal("Record.new passed something that is not an ast.StructTuple")
  end 
  o.decl = decl
  o.size = size
  o.fields = fields
  return setmetatable(o, Record)
end

Record.getSize = function(self)
  return self.size
end

Record.getFields = function(self)
  return self.fields
end

Record.getTypeName = function(self)
  return "Struct"
end

Record.castTo = function(self)
  return diag.cannot_cast_struct
end

local NamedRecord = Record:derive(type.Named)
type.NamedRecord = NamedRecord

NamedRecord.new = function(name, record)
  local o = {}
  o.name = name
  for k,v in pairs(record) do
    o[k] = v
  end
  return setmetatable(o, NamedRecord)
end

NamedRecord.getTypeName = function(self)
  return self.name
end

--- The type of an expression that resolves into a Type.
local TypeValue = Type:derive()
type.TypeValue = TypeValue

TypeValue.new = function(type)
  local o = {}
  o.type = type
  return setmetatable(o, TypeValue)
end

TypeValue.getTypeName = function(self)
  if self.type then
    return "TypeValue("..self.type:getTypeName()..")"
  else
    return "TypeValue"
  end
end

--- The type of any tuple we find to be empty. This is equivalent to 
--- C's 'void'.
local EmptyTuple = Type:derive()
type.EmptyTuple = EmptyTuple

type.EmptyTuple.getTypeName = function(self)
  return "()"
end

local Union = Type:derive()
type.Union = Union

Union.new = function(options)
  local o = {}
  assert(#options > 1, "Union.new passed less than one type.")
  o.options = cmn.List{}
  o.options_map = {}
  for opt in options:each() do
    if opt:is(type.Union) then
      for subopt in opt.options:each() do
        o.options:push(subopt)
        o.options_map[subopt] = true
      end
    else
      o.options:push(opt)
      o.options_map[opt] = true
    end
  end
  return setmetatable(o, Union)
end

Union.getTypeName = function(self)
  local buf = cmn.buffer.new()
  self.options:eachWithIndex(function(type,i)
    buf:put(type:getTypeName())
    if i ~= #self.options then
      buf:put(" | ")
    end
  end)
  return buf:get()
end

local Nil = Type:derive()
type.Nil = Nil

Nil.getTypeName = function()
  return "Nil"
end

local Closure = Type:derive()
type.Closure = Closure

Closure.new = function(expr)
  local o = {}
  o.expr = expr
  return setmetatable(o, Closure)
end

Closure.getTypeName = function(self)
  return "Closure"
end

local NamedClosure = Closure:derive(type.Named)
type.NamedClosure = NamedClosure

NamedClosure.new = function(name, closure)
  local o = {}
  o.name = name
  for k,v in pairs(closure) do
    o[k] = v
  end
  return setmetatable(o, NamedClosure)
end

NamedClosure.getTypeName = function(self)
  return "NamedClosure("..self.name..")"
end

return type
