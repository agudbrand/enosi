local cmn = require "common"
local log = require "lamulog"
local buffer = require "string.buffer"
local LuaType = require "Type"
local log = require "lamulog"
local util = require "util"

--- Diag type
local Diag = LuaType.make()

Diag.Severity =
{
  Fatal = 1,
  Error = 2,
  Warning = 3,
  Note = 4,
}

Diag.__call = function(self, ...)
  self:new(...)
  return self
end

Diag.new = function()
  return setmetatable({}, Diag)
end

--- Table of defined diagnostics.
local diag = {}

--- Helper for defining diagnostics.
local diagdef = cmn.indexer(function(_,key)
  if diag[key] then
    cmn.fatal("a diagnositc with name '",key,"' already exists")
  end

  local d = Diag.new()
  diag[key] = d
  d.name = key

  local parse,
        parse_severity,
        parse_emit,
        parse_new

  parse = cmn.indexer(function(_,key)
    if key == "severity" then
      return parse_severity
    elseif key == "emit" then
      return parse_emit
    elseif key == "new" then
      return parse_new
    else
      cmn.fatal("unknown diagdef key '",key,"'")
    end
  end)

  parse_severity = cmn.indexer(function(_,key)
    d.severity = Diag.Severity[key]
    assert(d.severity)
    return parse
  end)

  parse_emit = function(emit)
    d.emit = emit
    return parse
  end

  parse_new = function(new)
    d.new = new
    return parse
  end

  return parse
end)

local getLineAndColumnFromOffset = function(text, offset)
  local line = 1
  local column = 0
  for i=1,offset do
    if text:sub(i,i) == "\n" then
      line = line + 1
      column = 0
    else
      column = column + 1
    end
  end
  return line, column
end

local emitDiag = function(diag, message)
  local logf = 
  ({
    [Diag.Severity.Error] = log.error,
    [Diag.Severity.Fatal] = log.fatal,
    [Diag.Severity.Warning] = log.warn,
    [Diag.Severity.Note] = log.notice,
  })[diag.severity]

  print(diag.severity)

  logf(log, message, "\n")
end

local putDiagPrefix = function(buf, filename, line, column)
  buf:put(filename,":",line,":",column,": ")
end

local putDiagPrefixAtTok = function(buf, tok, parser)
  local l,c = getLineAndColumnFromOffset(parser.lex.buffer, tok.loc)
  putDiagPrefix(buf, parser.lex.filename, l, c)
end

diagdef.malformed_decl_entity
  .severity.Error
  .new(function(self, decl)
    self.decl = decl
  end)
  .emit(function(self, parser)
    local lex = parser.lex
    local buf = buffer.new()
    local decl = self.decl
    local start = decl.start
    putDiagPrefixAtTok(buf, start, parser)
    buf:put("malformed entity following declaration of id '",
            lex:getRaw(start), "'\n")
    emitDiag(self, buf:get())
  end)

local getTok = function(self, tok)
  self.tok = tok
end

local emitWrap = function(f)
  return function(self, parser)
    local buf = buffer.new()
    putDiagPrefixAtTok(buf, self.tok, parser)
    f(self, parser, buf)
    emitDiag(self, buf:get())
  end
end

local expected = function(msg)
  return emitWrap(function(self, parser, buf)
    buf:put("expected ", msg)
  end)
end

local message = function(...)
  local args = {...}
  return emitWrap(function(self, parser, buf)
    buf:put(unpack(args))
  end)
end

diagdef.expected_semicolon
  .severity.Error
  .new(getTok)
  .emit(expected "a semicolon")

diagdef.expected_expr
  .severity.Error
  .new(getTok)
  .emit(expected "an expression")

diagdef.tuple_expected_semi_or_rparen
  .severity.Error
  .new(getTok)
  .emit(expected "a ';' or ')'")

diagdef.expected_statement
  .severity.Error
  .new(getTok)
  .emit(expected "a statement")

diagdef.expected_value_or_type
  .severity.Error
  .new(getTok)
  .emit(expected "a type or value")

diagdef.expected_decl
  .severity.Error
  .new(getTok)
  .emit(expected "a declaration")

diagdef.expected_tuple
  .severity.Error
  .new(function(self, tok, kind)
    self.tok = tok
    self.kind = kind
  end)
  .emit(emitWrap(function(self, parser, buf)
    if self.kind then
      buf:put("expected a ", self.kind, " tuple")
    else
      buf:put("expected a tuple")
    end
  end))

diagdef.closure_arg_not_decl
  .severity.Error 
  .new(getTok)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("closure parameters must be declarations or identifiers to bind ",
            "to")
  end))

diagdef.redeclaration
  .severity.Error
  .new(function(self, decl, prevdecl)
    self.tok = prevdecl.start
    self.decl = decl
    self.prevdecl = prevdecl
  end)
  .emit(emitWrap(function(self, parser, buf)
    -- TODO(sushi) more detailed diag
    buf:put("redeclaration of '",self.decl:getId(parser.lex),"'")
  end))

diagdef.unknown_identifier
  .severity.Error
  .new(getTok)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("unknown identifier '",parser.lex:getRaw(self.tok),"'")
  end))

diagdef.unsized_field
  .severity.Error
  .new(getTok)
  .emit(message "unsized struct field")

diagdef.mismatched_initializer_type
  .severity.Error
  .new(function(self, field, arg)
    self.tok = arg.start
    self.field = field
    self.arg = arg
  end)
  .emit(emitWrap(function(self, parser, buf)
    local argt = self.arg.semantics.type
    local fieldt = self.field.semantics.type
    buf:put("type '", argt.name, "' cannot be used to initialize field '",
            self.field.semantics.name, "' of type '", fieldt.name, "'")
  end))

diagdef.attempt_to_cast_scalar_to_nonscalar
  .severity.Error
  .new(getTok)
  .emit(message "attempt to cast scalar to nonscalar")

diagdef.expected_named_expr
  .severity.Error
  .new(getTok)
  .emit(expected "a named expression")

diagdef.field_already_initialized
  .severity.Error
  .new(function(self, arg, preceeding_arg, fieldname)
    self.tok = arg.start
    self.arg = arg
    self.preceeding_arg = preceeding_arg
    self.fieldname = fieldname
  end)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("field '", self.fieldname, "' was already initialized")
  end))

diagdef.initializer_unknown_field
  .severity.Error
  .new(function(self, badname, arg, type)
    self.tok = arg.start
    self.badname = badname
    self.type = type
  end)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("no field named '",self.badname,"' in type '",self.type.name,"'")
  end))

diagdef.object_not_callable
  .severity.Error
  .new(getTok)
  .emit(message "object is not callable")

diagdef.initializer_not_record
  .severity.Error
  .new(getTok)
  .emit(message "attempt to initialize a type that is not a struct")

diagdef.expected_rbrace_or_semicolon
  .severity.Error
  .new(getTok)
  .emit(expected "';' to end statement or '}' to close block")

diagdef.is_lhs_not_union
  .severity.Warning
  .new(getTok)
  .emit(message "redundant if ..is expression, subject is not a union")

diagdef.is_rhs_not_in_union
  .severity.Error
  .new(function(self, node)
    self.tok = node.rhs.start
    self.node = node
  end)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("rhs of 'is' type, '", 
            self.node.rhs.semantics.type.type:getTypeName(),
            "', does not match any type of lhs union type '",
            self.node.lhs.semantics.type:getTypeName(), "'")
  end))

diagdef.cannot_cast_struct
  .severity.Error
  .new(getTok)
  .emit(message "implicit cast from structs is not supported yet")

diagdef.access_non_structural_type
  .severity.Error
  .new(function(self, access)
    self.tok = access.start
    self.access = access
  end)
  .emit(emitWrap(function(self, parser, buf)
    local type = require "type"
    local lhst = self.access.lhs.semantics.type
    if lhst:is(type.Scalar) then
      buf:put("attempt to access scalar type ", lhst:getTypeName())
    else
      buf:put("attempt to access non-structural type ", lhst:getTypeName())
    end
  end))

diagdef.nonexistant_field_access
  .severity.Error
  .new(function(self, access, id)
    self.tok = access.start
    self.id = id
    self.access = access
  end)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("type ", self.access.lhs.semantics.type:getTypeName(), 
            " has no field named '", self.id, "'")
  end))

diagdef.binop_not_defined
  .severity.Error
  .new(function(self, op, lhst, rhst)
    self.tok = op.start
    self.op = op
    self.lhst = lhst
    self.rhst = rhst
  end)
  .emit(emitWrap(function(self, parser, buf)
    buf:put("binop ", tostring(self.op.kind), " not defined between ",
            self.lhst:getTypeName(), " and ", self.rhst:getTypeName())
  end))

diag.Diag = Diag

return diag
