---
--- Performs semantic analysis on the AST produced by the parser.
---

local function lua_type(x)
  return type(x)
end

local cmn = require "common"
local ast = require "ast"
local ffi = require "ffi"
local diag = require "diag"
local co = require "coroutine"
local Token = require "token"
local type = require "type"
local log = require "lamulog"
local util = require "util"

local Diag = diag.Diag

local Sema,
      Scope

Sema = cmn.LuaType.make()

Sema.lazy = {}
Sema.done = {}
Sema.err = {}

Sema.new = function(parser)
  local o = {}
  o.parser = parser
  o.nodes = {}
  o.depth = 0
  o.scope = Scope.new()
  
  setmetatable(o, Sema)

  for k,v in pairs(type.builtin) do
    local decl = 
      ast.BuiltinDecl
      {
        id = ast.Id { start = Token.newVirtual(Token.Kind.Identifier, k) }
      }
    decl.semantics.type = type.TypeValue.new(v)
    o.scope:recordDecl(o, decl)
    o.nodes[decl] = true
  end

  local decl = 
    ast.BuiltinDecl
    {
      id = ast.Id { start = Token.newVirtual(Token.Kind.Identifier, "Nil") }
    }
  decl.semantics.type = type.TypeValue.new(type.Nil)
  o.scope:recordDecl(o, decl)
  o.nodes[decl] = true

  return o
end

Sema.incDepth = function(self)
  self.depth = self.depth + 1
end

Sema.decDepth = function(self)
  self.depth = self.depth - 1
end

Sema.printLine = function(self, ...)
  if true then
    for _=1,self.depth do
      log:info " "
    end

    log:info(...)
    log:info("\n")
  end
end

Sema.yield = function(self, obj)
  return co.yield(obj)
end

Sema.enterScope = function(self)
  self.scope = Scope.new(self.scope)
  return self.scope
end

Sema.leaveScope = function(self, node)
  self.scope = self.scope.prev.scope
  assert(node)
  node.semantics.began_scope = self.scope
end

Scope = cmn.LuaType.make()

Scope.new = function(prev)
  local o = {}
  o.decls = 
  {
    map = {},
    list = cmn.List{},
  }
  o.transforms = {}
  o.queue = {}
  if prev then
    o.prev = { scope=prev, limit=#prev.decls.list }
    for k,v in pairs(prev.queue) do
      o.transforms[k] = v
    end
    prev.queue = {}
  end
  return setmetatable(o, Scope)
end

Scope.dump = function(self, sema)
  log:warn(
    "------------------------------\n",
    "scope dump: \n")
  self:eachDecl(nil, function(decl)
    decl:dump(sema.parser)
  end)
end

--- Signals 'each*' to stop iterating.
Scope.stop = {}

--- Iterates each decl visible in this scope.
Scope.eachLocalDecl = function(self, limit, f)
  limit = limit or #self.decls.list
  for i=limit,1,-1 do
    if f(self.decls.list[i]) == Scope.stop then
      return self.decls.list[i]
    end
  end
end

--- Iterates each decl this scope can see in reverse up to 'limit'.
Scope.eachDecl = function(self, limit, f)
  limit = limit or #self.decls.list
  local locdec = self:eachLocalDecl(limit, f)
  if locdec then
    return locdec
  end
  if self.prev then
    return self.prev.scope:eachDecl(self.prev.limit, f)
  end
end

Scope.recordDecl = function(self, sema, decl)
  local declid = decl:getId(sema.parser.lex)
  self:eachLocalDecl(nil, function(prevdecl)
    if prevdecl:getId(sema.parser.lex) == declid then
      sema:yield(diag.redeclaration(decl, prevdecl))
    end
  end)
  self.decls.list:push(decl)
  self.decls.map[declid] = decl
end

Scope.findDecl = function(self, sema, name)
  return self:eachDecl(nil, function(decl)
    local dname = decl:getId(sema.parser.lex)
    if name == dname then
      return Scope.stop
    end
  end)
end

Scope.recordTransform = function(self, var, node, nutype)
  if self.transforms[var] then
    cmn.fatal("attempt to trasform var twice")
  end

  self.transforms[var] =
  {
    node=node,
    nutype=nutype
  }
end

--- Queues a transform that will be applied to the next created
--- scope.
Scope.queueTransform = function(self, var, node, nutype)
  if self.queue[var] then
    cmn.fatal("attempt to transform var twice")
  end

  self.queue[var] =
  {
    node=node,
    nutype=nutype
  }
end

Scope.resolveType = function(self, var)
  local transform = self.transforms[var]
  if not transform then
    if self.prev then
      return self.prev.scope:resolveType(var)
    end
    return var.semantics.type
  end
  return transform.nutype
end

local handlers = {}

Sema.on = function(self, node)
  if not node then
    cmn.fatal("Sema.on passed a nil node")
  end

  local handler = self.nodes[node]
  if handler == true then
    return Sema.done
  end

  if not handler then
    if node.semantics.complete then
      self.nodes[node] = true
      return Sema.done
    end

    handler = handlers[node.node_kind]
    if not handler then
      cmn.fatal("sema encountered unhandled node kind '",node.node_kind.name,
                "'")
    end
    handler = cmn.pco(handler)
    self.nodes[node] = handler
  end

  self:printLine("analyzing ", node.node_kind.name)

  self:incDepth()
  local success, obj = co.resume(handler, self, node) 
  if not success then
    error(obj)
  end
  self:decDepth()

  self:printLine("done with ", node.node_kind.name)

  if obj == Sema.done then
    self.nodes[node] = true
    node.semantics.complete = true
  end

  return obj
end

Sema.complete = function(self, node)
  while true do
    local result = self:on(node)
    if result == Sema.done then
      return true
    elseif not result or result == Sema.err then
      self:yield(Sema.err)
    elseif result ~= Sema.lazy and result:is(Diag) then
      result:emit(self.parser)
      self:yield(Sema.err)
    end
  end
end

--- Define a node kind handler.
Sema.handle = function(node_kind, handler)
  if handlers[node_kind] then
    cmn.fatal("a handler has already been defined for node '",node_kind.name,
              "'")
  end
  handlers[node_kind] = handler
end

Sema.handle(ast.BuiltinDecl, function()
  return Sema.done
end)

--- Basic check if a symbol exists when encountering an IdRef without
--- trying to complete the declaration it refers to.
--- TODO(sushi) move this into IdRef handler and make it lazy. Kinda sucks, 
---             though as we currently don't have a way to yield values.
Sema.requireSymbol = function(self, lex, tok)
  local decl = self.scope:findDecl(self, lex:getRaw(tok))
  if not decl then
    self:yield(diag.unknown_identifier(tok))
  end
  return decl
end

Sema.findSymbol = function(self, lex, tok)
  return self.scope:findDecl(self, lex:getRaw(tok))
end

Sema.handle(ast.IdRef, function(self, ref)
  local decl = self:requireSymbol(self.parser.lex, ref.start)

  self:complete(decl)

  ref.semantics.type = self.scope:resolveType(decl)

  return Sema.done
end)

Sema.handle(ast.Literal, function(self, literal)
  local tk = literal.start.kind
  local raw = self.parser.lex:getRaw(literal.start)
  if tk == Token.Kind.String then
    cmn.fatal("TODO(sushi) handle string literals")
  elseif tk == Token.Kind.Integer then
    literal.semantics.type = type.builtin.s64
    literal.semantics.value = ffi.new("s64", tonumber(raw))
  elseif tk == Token.Kind.Float then
    literal.semantics.type = type.builtin.f64
    literal.semantics.value = ffi.new("f64", tonumber(raw))
  elseif tk == Token.Kind.True then
    literal.semantics.type = type.builtin.b8
    literal.semantics.value = ffi.new("b8", 1)
  elseif tk == Token.Kind.False then
    literal.semantics.type = type.builtin.b8
    literal.semantics.value = ffi.new("b8", 0)
  else
    cmn.fatal("unhandled literal token kind: ", tostring(tk))
  end
  return Sema.done
end)

Sema.handle(ast.BinOp, function(self, op)
  self:complete(op.lhs)
  self:complete(op.rhs)
  local lhs = op.lhs
  local rhs = op.rhs
  local lhst = op.lhs.semantics.type
  local rhst = op.rhs.semantics.type

  local handlePointerScalarArithmetic = function()
    if rhs.type:is(type.Floating) then
      self:yield(diag.float_in_pointer_arithmetic(op.rhs.start))
    end

    if op.kind.is_additive then
      local subtype = lhs.type.subtype
      op.semantics.rhs_mul = subtype.size
    elseif op.kind.is_comparative then
      self:yield(diag.comparison_between_pointer_and_scalar(op.start))
    end
  end

  local handleScalarScalarArithmetic = function()
    if op.kind:is(ast.BinOp.Kind.Mod) then
      if lhst:is(type.Floating) and rhst:is(type.Floating) then
        self:yield(diag.mod_not_defined_between_floats(op.start))
      end
    end

    if lhst == rhst then
      op.semantics.type = lhst
      return
    end

    local take_left = 
      type.Scalar.decideBinaryOpType(lhst, rhst)

    if take_left then
      rhs.semantics.cast_to = lhst
      op.semantics.type = lhst
    else
      lhs.semantics.cast_to = rhst
      op.semantics.type = rhst
    end

    rhs:dump(self.parser)
    lhs:dump(self.parser)
  end

  local handleAssignmentToUnion = function()
    self:printLine("handling assignment to union")
    local best
    local best_score = 0
    for opt in lhst.options:each() do
      if opt == rhst then
        -- Always take matching option.
        best = opt 
        break
      end

      local cast = rhst:castTo(opt)
      if cast == true then
        -- Only consider if we find we can cast.
        local score = 0
        local addScore = function(x) score = score + x end
        if opt:is(type.Scalar) and rhst:is(type.Scalar) then
          if opt:is(type.Signed) then
            if rhst:is(type.Signed) then
              addScore(10)
            else
              addScore(5)
            end
          elseif opt:is(type.Unsigned) then
            if rhst:is(type.Unsigned) then
              addScore(10)
            else
              addScore(5)
            end
          end

          if opt:is(type.Integral) then
            if rhst:is(type.Integral) then
              addScore(20)
            else
              addScore(5)
            end
          elseif opt:is(type.Floating) then
            if rhst:is(type.Floating) then
              addScore(20)
            else
              addScore(5)
            end
          end

          if opt.size == rhst.size then
            addScore(15)
          elseif opt.size > rhst.size then
            addScore(10)
          else
            addScore(5)
          end

          if score > best_score then
            best_score = score
            best = opt
          end
        else
          self:yield(diag.nonscalar_union_assignment(op.start))
        end -- if scalar
      end -- if cast
    end

    if not best then
      self:yield(diag.impossible_assign_to_union(op.start))
    end
    
    op.semantics.type = best
    if best ~= rhst then
      rhs.semantics.cast_to = best
    end

    if lhs:is(ast.IdRef) then
      -- Record the resolution of this variable's type.
      self.scope:recordTransform(
        lhs.decl,
        op,
        best)
    end

    self:printLine("chose ", best:getTypeName())
  end

  local handleAssignment = function()
    if lhst == rhst then
      op.semantics.type = lhst
    else
      local cast = rhst:castTo(lhst)
      if cast == true then
        rhst.semantics.cast_to = lhst
        op.semantics.type = lhst
      else
        self:yield(cast(op.start))
      end
    end
  end

if op.kind == ast.BinOp.Kind.Assign then
    if lhst:is(type.Union) then
      handleAssignmentToUnion()
    else
      handleAssignment()
    end
  elseif lhst:is(type.Pointer) and rhst:is(type.Scalar) then
    handlePointerScalarArithmetic()
  elseif lhst:is(type.Scalar) and rhst:is(type.Scalar) then
    handleScalarScalarArithmetic()
  else
    self:yield(diag.binop_not_defined(op, lhst, rhst))
  end

  return Sema.done
end)

Sema.handle(ast.Block, function(self, block)
  for stmt in block.statements:each() do
    self:complete(stmt)
  end

  if block.final_operand then
    self:complete(block.final_operand)
    block.semantics.type = block.final_operand.semantics.type
  else
    block.semantics.type = type.EmptyTuple
  end

  return Sema.done
end)

Sema.typeCheckArg = function(self, param, arg)
  param:dump(self.parser)
  if param.semantics.type ~= arg.semantics.type then
    local cast = param.semantics.type:castTo(arg.expr.semantics.type)
    if cast == true then
      arg.expr.semantics.cast_to = param.semantics.type
    else
      self:yield(cast(arg.start))
    end
  end
end

Sema.handle(ast.DeclTuple, function(self, tuple)
  for elem in tuple.elements:each() do
    self:complete(elem)
  end

  return Sema.done
end)

Sema.handle(ast.Closure, function(self, closure)
  local param_map = {}
  for param in closure.params.elements:each() do
    param_map[param:getId(self.parser.lex)] = param
  end

  closure.semantics.instantiator = function(args)
    local initialized = 
    {
      map = {},
      list = cmn.List{}
    }
    local recordInitialized = function(name, expr)
      initialized.map[name] = expr
      initialized.list:push { name=name, expr=expr }
    end

    for arg,i in args.elements:eachWithIndex() do
      if arg:is(ast.NamedExpr) then
        local name = self.parser.lex:getRaw(arg.start)
        
        local initializing_arg = initialized[name]
        if initializing_arg then
          self:yield(
            diag.param_already_initialized(arg, initializing_arg, name))
        end

        local param = param_map[name]
        if not param then
          self:yield(
            diag.nonexistant_param(arg, name))
        end

        self:complete(arg.expr)

        if not param:is(ast.UnboundClosureParam) then
          self:typeCheckArg(param, arg.expr)
        end

        recordInitialized(name, arg.expr)
      else
        local param = closure.params.elements[i]
        if not param then
          self:yield(diag.too_many_closure_args(closure, args))
        end

        self:complete(arg)

        if not param:is(ast.UnboundClosureParam) then
          self:typeCheckArg(param, arg)
        end

        recordInitialized(param:getId(self.parser.lex), arg)
      end
    end

    local resolved_params = {}

    local inst_params = closure.params:fork
    {
      [ast.UnboundClosureParam] = function(node)
        -- Replace this node with a proper param.
        local name = node:getId(self.parser.lex)
        local arg = initialized.map[name]
        local param
        if not arg then
          local tok = Token.newVirtual(Token.Kind.Identifier, "Nil")
          param = 
            ast.VarDecl
            {
              id = ast.Id { start = node.start },
              type = ast.IdRef 
              {
                start = tok,
                decl = self:requireSymbol(self.parser.lex, tok),
              }
            }
        else
          local argt
          if arg:is(ast.NamedExpr) then
            argt = arg.expr.semantics.type
          else
            argt = arg.semantics.type
          end

          param = 
            ast.VarDecl
            {
              id = ast.Id { start = node.id.start },
            }

          param.semantics.type = argt
          param.semantics.complete = true
        end
        resolved_params[name] = param
        return param
      end
    }

    local inst_body = closure.body:fork
    {
      [ast.UnboundIdRef] = function(x)
        local name = self.parser.lex:getRaw(x.start)
        local param = resolved_params[name]

        local ref = ast.IdRef
        {
          start = x.start,
          decl = param,
        }
        ref.semantics.complete = true
        ref.semantics.type = param.semantics.type

        return ref
      end
    }

    self:complete(inst_params)
    self:complete(inst_body)

    local instantiated = ast.InstantiatedClosure
    {
      params = inst_params,
      body = inst_body,
    }

    instantiated:dump(self.parser)

    return instantiated
  end

  closure.semantics.type = type.Closure.new(closure)

  return Sema.done
end)

Sema.handle(ast.ValueTuple, function(self, vtuple)
  if not vtuple.elements or 0 == #vtuple.elements then
    vtuple.semantics.type = type.EmptyTuple
  else
    vtuple.elements:each(function(elem)
      self:complete(elem)
    end)
  end
  return Sema.done
end)

Sema.handle(ast.Call, function(self, call)
  self:complete(call.callee)
  self:complete(call.args)

  local calleet = call.callee.semantics.type

  local handleTypeValueCall = function()
    local named
    local callee_type = call.callee.semantics.type.type
    if callee_type:is(type.NamedRecord) then
      named = callee_type
    end
    if not callee_type:is(type.Record) then
      self:yield(diag.initializer_not_record(call.callee.start))
    end
    call.semantics.type = named or callee_type

    local initialized = 
    {
      map = {},
      list = cmn.List{}
    }
    local recordInitialized = function(name, expr)
      initialized.map[name] = expr
      initialized.list:push { name=name, expr=expr }
    end

    call.args.semantics.complete = true

    for arg,i in call.args.elements:eachWithIndex() do
      if arg:is(ast.NamedExpr) then
        local name = self.parser.lex:getRaw(arg.id.start)

        local initializing_arg = initialized.map[name]
        if initializing_arg then
          self:yield(
            diag.field_already_initialized(arg, initializing_arg, name))
        end

        local field = callee_type.fields.map[name] 

        if not field then
          self:yield(
            diag.initializer_unknown_field(
              name, 
              arg, 
              callee_type))
        end

        self:complete(arg.expr)

        if field.semantics.type ~= arg.expr.semantics.type then
          local cast = field.semantics.type:castTo(arg.expr.semantics.type)
          if cast == true then
            arg.expr.semantics.cast_to = field.semantics.type
          elseif type(cast) == "table" and cast:is(Diag) then
            self:yield(cast(arg.start))
          else
            self:yield(diag.mismatched_initializer_type(field, arg))
          end
        end

        arg.id.semantics.complete = true
        arg.semantics.complete = true

        recordInitialized(name, arg.expr)
      else
        self:complete(arg)

        local field = callee_type.fields.list[i]

        if field.semantics.type ~= arg.semantics.type then
          local cast = field.semantics.type:castTo(arg.semantics.type)
          if cast == true then
            arg.semantics.cast_to = field.semantics.type
          else 
            self:yield(cast(arg.start))
          end
        end

        recordInitialized(field.semantics.name, arg)
      end
    end
  end

  local handleClosureCall = function()
    self:complete(call.callee)

    util.dumpValue(call.callee.semantics.type, 2)

    local closure = call.callee.semantics.type.expr

    local instantiated = 
      closure.semantics.instantiator(call.args)

    call.semantics.type = instantiated.body.semantics.type
  end

  -- Verify that this is something we can call.
  if calleet:is(type.TypeValue) then
   
    handleTypeValueCall()
  elseif calleet:is(type.Closure) then
    handleClosureCall()
  else
    self:yield(diag.object_not_callable(call.callee.start))
  end

  return Sema.done
end)

Sema.handle(ast.StructTuple, function(self, struct, scope)
  -- Enter a scope to capture declarations inside of this struct.

  local fields = {}
  local fields_list = cmn.List{}

  local size = 0
  for decl in struct.elements:each() do
    self:complete(decl)
    if not decl.semantics.type:is(type.Sized) then
      self:yield(diag.unsized_field(decl.start))
    end
    decl.semantics.offset = size
    decl.semantics.name = decl:getId(self.parser.lex)
    size = size + decl.semantics.type:getSize()
    fields[decl.semantics.name] = decl
    fields_list:push(decl)
  end

  struct.semantics.type = 
    type.TypeValue.new(
      type.Record.new(
        struct, 
        size, 
        {
          map = fields,
          list = fields_list
        }))
  struct.semantics.field_scope = scope

  return Sema.done
end)

Sema.handle(ast.VarDecl, function(self, decl)
  decl.id.semantics.complete = true

  self:yield(Sema.lazy)

  if not decl.type and decl.expr then
    -- Infer the type from the expression.
    self:complete(decl.expr)
    local expr_type = decl.expr.semantics.type
    if expr_type:is(type.TypeValue) then
      decl.semantics.type = 
        type.TypeValue.new(
          type.NamedRecord.new(
            decl:getId(self.parser.lex),
            decl.expr.semantics.type.type))
    elseif expr_type:is(type.Closure) then
      decl.semantics.type = 
        type.NamedClosure.new(
          decl:getId(self.parser.lex),
          decl.expr.semantics.type)
    else
      decl.semantics.type = decl.expr.semantics.type
    end
  elseif not decl.expr and decl.type then
    self:complete(decl.type)
    if not decl.type.semantics.type:is(type.TypeValue) then
      self:yield(diag.expected_type_value(decl.type.start))
    end
    decl.semantics.type = decl.type.semantics.type.type
  else
    -- Otherwise, ensure the expression matches the specified type.
    cmn.fatal("TODO(sushi) handle explicit var decl types with expr")
  end

  return Sema.done
end)

Sema.handle(ast.ExprStmt, function(self, exprstmt)
  self:complete(exprstmt.expr)
  return Sema.done
end)

Sema.handle(ast.Union, function(self, union)
  local opts = cmn.List{}

  for opt in union.options:each() do
    self:complete(opt)
    local opt_type = opt.semantics.type
    if not opt_type:is(type.TypeValue) then
      self:yield(diag.union_option_not_type())
    end
    opts:push(opt_type.type)
  end

  union.semantics.type = 
    type.TypeValue.new(type.Union.new(opts))

  return Sema.done
end)

Sema.handle(ast.If, function(self, ifexpr)
  local cond = ifexpr.cond
  local body = ifexpr.body
  local alt = ifexpr.alt

  self:enterScope(ifexpr)

  local is_is = cond:is(ast.IsExpr)

  if is_is then
    self:complete(cond.lhs)
    if not cond.lhs:is(ast.IdRef) then
      self:yield(diag.is_lhs_not_lvalue(cond.lhs.start))
    end

    local lhst = cond.lhs.semantics.type

    if not lhst:is(type.Union) then
      diag.is_lhs_not_union(cond.lhs.start):emit(self.parser)
    end

    self:complete(cond.rhs)

    local rhst = cond.rhs.semantics.type
    if not rhst:is(type.TypeValue) then
      self:yield(diag.rhs_of_is_is_not_type_val(cond.start))
    end

    if not lhst.options_map[rhst.type] then
      self:yield(diag.is_rhs_not_in_union(cond))
    end

    self.scope:queueTransform(
      cond.lhs.decl, 
      cond,
      cond.rhs.semantics.type.type)

    cond.semantics.complete = true
  else
    self:complete(cond)
    if not cond.semantics.type:is(type.Scalar) then
      self:yield(diag.if_cond_not_scalar(cond.start))
    end
  end

  self:complete(body)

  local body_type = body.semantics.type

  local alt_type
  if alt then
    self:complete(alt)
    alt_type = alt.semantics.type
  else
    alt_type = type.Nil
  end

  local if_type
  if alt_type then
    if alt_type ~= body_type then
      if_type = type.Union.new(cmn.List{body_type, alt_type})
    else
      if_type = body_type
    end
  else
    if_type = body_type
  end

  ifexpr.semantics.type = if_type

  self:leaveScope()

  return Sema.done
end)

Sema.handle(ast.Access, function(self, access)
  self:complete(access.lhs)

  local lhst = access.lhs.semantics.type

  if not lhst:is(type.Record) then
    self:yield(diag.access_non_structural_type(access))
  end

  local rhsid = self.parser.lex:getRaw(access.rhs.start)

  local field = lhst.fields.map[rhsid]
  if not field then
    self:yield(diag.nonexistant_field_access(access, rhsid))
  end

  access.rhs.semantics.complete = true

  access.semantics.type = field.semantics.type

  return Sema.done
end)

return Sema
