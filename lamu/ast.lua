---
--- Structure of the AST.
---

local cmn = require "common"
local log = require "lamulog"
local Token = require "token"
local util = require "util"

local ast = setmetatable({},
{
  __index = function(self, k)
    return self.node_types[k]
  end
})

ast.node_types = {}

ast.Node = cmn.LuaType.make()
ast.node_types.Node = ast.Node

ast.NodeInstance = cmn.LuaType.make()

-- ast.NodeInstance.__tostring = function(self)
--   return self.node_kind.name
-- end

ast.NodeInstance.new = function(node_kind, params)
  local o = 
  {
    children = cmn.List{},
    semantics = {},
    start = params.start,
    stop = params.stop
  }

  o.node_kind = node_kind

  -- Type check and assign the given params.
  local schema = node_kind.schema

  local processParam = function(k, v)
    local prop = schema.props[k]
    if prop then
      if not v:is(prop) then
        cmn.fatal("incorrect type passed to prop '",k,"'")
      end
      o[k] = v
      return
    end

    local node = schema.nodes.map[k]
    if node then
      if v:is(cmn.List) then
        if not node:is(ast.NodeList) then
          cmn.fatal("only Lists can be passed to NodeList nodes")
        end
        o[k] = v
      else
        if not v:is(node) then
          cmn.fatal("incorrect type passed to node '",k,"': ",
                    v.node_kind.name, ", wanted: ", node.name)
        end
        o[k] = v
      end
      return
    end

    cmn.fatal("unknown key '",k,"' passed to params for node")
  end

  for k,v in pairs(params) do
    processParam(k,v)
  end

  -- Build the child node list in the correct order by matching names.
  node_kind.schema.nodes.list:each(function(defchild)
    local inschild = o[defchild.name]
    if inschild then
      inschild.parent = o
      o.children:push(inschild)
    end
  end)

  -- Take on methods.
  for m,f in pairs(node_kind.schema.methods) do
    o[m] = f
  end

  -- Ensure that this node instance has a start and stop token and
  -- throw an error if we are unable to find at least a start token.
  if o.start and not o.stop then
    -- Assume this is a single token node and set its stop to start.
    o.stop = o.start
  elseif not o.start and o.stop then
    -- This doesn't make sense so fail.
    cmn.fatal("found node with a stop token but no start token")
  elseif not o.start and not o.stop then
    -- Retrieve start and stop tokens from the first and last 
    -- child nodes. If everything has gone correctly up to this point
    -- this should be ok to do.
    if 0 == o.children:len() then
      cmn.fatal("cannot resolve start and stop tokens for node as it has no ",
                "children")
    end
    
    local getStartStopFromNode = function(node)
      if node:is(cmn.List) then
        return
          node[1].start,
          node[#node].stop
      else
        return node.start, node.stop
      end
    end

    if 1 == o.children:len() then
      local child = o.children[1]
      o.start, o.stop = getStartStopFromNode(child)
      if not o.start or not o.stop then
        cmn.fatal("node child is missing start or stop token")
      end
    else
      local first_start = getStartStopFromNode(o.children[1])
      local _,last_stop = getStartStopFromNode(o.children[#o.children])
      if not first_start then
        cmn.fatal("first child of node missing start token")
      end
      if not last_stop then
        cmn.fatal("last child of node missing stop token")
      end
      o.start = first_start
      o.stop = last_stop
    end
  end

  return setmetatable(o, ast.NodeInstance)
end

ast.NodeInstance.is = function(self, T)
  if T == ast.NodeInstance then
    return true
  end
  return self.node_kind:is(T)
end

ast.NodeInstance.fork = function(self, cb)
  cb = cb or {}
  local relocations = {}
  local type = require "type"

  local function deepCopy(x)
    local function impl()
      if cmn.type(x) ~= "table" then
        return x
      else
        if relocations[x] then
          return relocations[x]
        end

        if cmn.List:isTypeOf(x) then
          local o = cmn.List{}
          relocations[x] = o
          for elem in x:each() do
            o:push(deepCopy(elem))
          end
          return o
        end

        if ast.NodeInstance:isTypeOf(x) then
          if cb[x.node_kind] then
            local result = cb[x.node_kind](x)
            if result then
              relocations[x] = result
              return result
            end
          else
            local o = {}
            relocations[x] = o
            o.semantics = setmetatable({}, {__index = x.semantics})
            o.children = cmn.List{}

            for child in x.children:each() do
              local result = deepCopy(child)
              o.children:push(result)
            end

            for k,v in pairs(x) do
              if x.node_kind.schema.nodes.map[k] then
                o[k] = deepCopy(v)
              end
            end

            return setmetatable(o, {__index = x})
          end
        end

        local o = {}
        relocations[x] = o
        for i,v in ipairs(x) do
          o[i] = deepCopy(v)
        end
        for k,v in pairs(x) do
          if k == "parent" then
          elseif k == "node_kind" then
            o[k] = v
          else
            o[k] = deepCopy(v)
          end
        end
        return setmetatable(o, getmetatable(x))
      end
    end

    local result = impl()
    return result
  end

  return (deepCopy(self))
end

ast.NodeInstance.dump = function(self, parser)
  local buf = cmn.buffer.new()
  local function dump(node, depth)
    local indent = function(offset)
      for i=1,depth+offset do
        buf:put " "
      end
    end
    local line = function(offset, ...)
      indent(offset)
      buf:put(...)
      buf:put "\n"
    end
    if node:is(cmn.List) then
      node:each(function(elem)
        dump(elem, depth)
      end)
    else
      indent(0)
      buf:put(node.node_kind.name, " ")

      if not node.semantics.complete then
        buf:put "<I> "
      end

      if node.node_kind.writeValue then
        buf:put "= "
        node.node_kind.writeValue(node, buf, parser)
      end

      buf:put "\n"

      local infostack = cmn.List{}

      local semantics = node.semantics
      if semantics.complete then
        if semantics.type then
          infostack:push("type: "..node.semantics.type:getTypeName())
        end
        if semantics.cast_to then
          infostack:push("cast_to: "..semantics.cast_to:getTypeName())
        end
        if semantics.began_scope then
          local scope = semantics.began_scope
          for k,v in pairs(scope.transforms) do
            infostack:push(
              "transform "..k:getId(parser.lex)..": "..
              k.semantics.type:getTypeName().." -> "..v.nutype:getTypeName())
          end
        end
      end

      infostack:eachWithIndex(function(info,i)
        indent(0)
        if i == #infostack then
          buf:put("` ")
        else
          buf:put("| ")
        end
        buf:put(info, "\n")
      end)

      node.children:each(function(child)
        dump(child, depth + 1)
      end)
    end
  end

  dump(self, 0)

  log:notice(buf:get(),"\n")
end

ast.Node.schema = 
{
  props = 
  {
    start = Token,
    stop = Token,
  },
  nodes =
  {
    list = cmn.List{},
    map = {},
  },
  methods = {}
}

ast.Node.derive = function(self, name)
  if ast.node_types[name] then
    cmn.fatal("ast.Node type '",name,"' already exists")
  end

  local N = 
  {
    name = name,
    schema = 
    {
      props = {}, 
      nodes = 
      {
        list = cmn.List{},
        map = {},
      },
      methods = {},
    },
  }

  setmetatable(N, 
  {
    __index = self,
    __call = function(self, params)
      return ast.NodeInstance.new(self, params)
    end
  })

  ast.node_types[name] = N

  -- Inherit properties of base node kind.
  -- TODO(sushi) perform nested lookups instead of storing these things 
  --             several times maybe.
  for k,v in pairs(self.schema.props) do
    N.schema.props[k] = v
  end

  for n in self.schema.nodes.list:each() do
    N.schema.nodes.list:push(n)
    N.schema.nodes.map[n.name] = n.type
  end

  for m,f in pairs(self.schema.methods) do
    N.schema.methods[m] = f
  end

  N.new = function(self, params)
    return ast.Node.new(self, params)
  end

  local disallowChildrenKey = function(key)
    if key == "children" then
      cmn.fatal "an ast.Node cannot specify 'children' as one of its fields"
    end
  end

  local kind_indexer,
        prop_indexer,
        node_indexer,
        writeValue_indexer,
        method_indexer

  -- .[node | prop | writeValue | ...]
  kind_indexer = cmn.indexer(function(_,k)
    if k == "prop" then
      return prop_indexer
    elseif k == "node" then
      return node_indexer
    elseif k == "writeValue" then
      return writeValue_indexer
    elseif k == "method" then
      return method_indexer
    else
      cmn.fatal("unknown ast.Node field kind '",k,"'")
    end
  end)

  -- .prop(<type>)
  prop_indexer = function(type)
    -- .prop(<type>) "<name>"
    return function(name)
      disallowChildrenKey(name)
      if N.schema.props[name] then
        cmn.fatal("node type '",N.name,"' already defines or inherits property '",
              name, "'")
      end
      N.schema.props[name] = type
      return kind_indexer
    end
  end

  local lookupNodeType = function(name)
    local SubN = ast.node_types[name]
    if not SubN then
      cmn.fatal("undefined node type '",name,"'")
    end
    return SubN
  end

  -- .node[.list].<k>
  node_indexer = cmn.indexer(function(_,k)
    local getName = function(type)
      return function(name)
        disallowChildrenKey(name)
        if N.schema.nodes.map[name] then
          cmn.fatal("node type '",N.name,"' already defines or inherits node ",
                "field '",name,"'")
        end
        N.schema.nodes.map[name] = type
        N.schema.nodes.list:push { name=name, type=type }
        return kind_indexer
      end
    end

    if k == "list" then
      return cmn.indexer(function(_,subtype)
        local SubN = lookupNodeType(subtype)
        local list = ast.NodeList.new(SubN)
        return getName(list)
      end)
    else
      local SubN = lookupNodeType(k)
      -- .node.<k> "<name>"
      return getName(SubN)
    end
  end)

  -- .writeValue(<f>)
  writeValue_indexer = function(f)
    N.writeValue = f
    return kind_indexer
  end

  method_indexer = cmn.indexer(function(_,k)
    if N.schema.methods[k] then
      cmn.fatal("node type '",N.name,"' alread defines or inherits method '",
                k, "'")
    end
    return function(f)
      N.schema.methods[k] = f
      return kind_indexer
    end
  end)

  return kind_indexer
end

local indent = function(n)
  for i=1,n do
    log:notice(" ")
  end
end

ast.Node.dump = function(self, depth)
  depth = depth or 0
  local line = function(d, ...)
    indent(depth+d)
    log:notice(...)
    log:notice("\n")
  end

  line(0, self.name)
  line(1, "props:")
  for p in pairs(self.schema.props) do
    line(2, p)
  end

  if 0 ~= #self.schema.nodes.list then
    line(1, "nodes:")
    for n in self.schema.nodes.list:each() do
      line(2, n.name, ": ")
      n.type:dump(depth + 3)
    end
  end
end

-- Special value that indicates that a subnode of a Node kind stores a list 
-- of nodes rather than just one.
ast.NodeList = cmn.LuaType.make()

ast.NodeList.new = function(subtype)
  return setmetatable({subtype=subtype}, ast.NodeList)
end


-- * --------------------------------------------------------------------------
-- * --------------------------------------------------------------------------
-- * --------------------------------------------------------------------------


ast.Node:derive "Id"
  .writeValue(function(self, buf, parser)
    buf:put(parser.lex:getRaw(self.start))
  end)

ast.Node:derive "Stmt"
ast.Node:derive "Expr"

ast.Expr:derive "Union"
  .node.list.Expr "options"

ast.Stmt:derive "ExprOrDeclStmt"

ast.ExprOrDeclStmt:derive "ExprStmt"
  .node.Expr "expr"

ast.ExprOrDeclStmt:derive "Decl"
  .node.Id "id"
  .method.getId(function(self, lex)
    return lex:getRaw(self.id.start)
  end)

ast.Expr:derive "IdRef"
  .prop(ast.Decl) "decl"
  .writeValue(function(self, buf, parser)
    buf:put(parser.lex:getRaw(self.start))
  end)

ast.Expr:derive "Literal"
  .writeValue(function(self, buf, parser)
    buf:put(parser.lex:getRaw(self.start))
  end)

ast.Expr:derive "Block"
  .node.list.Stmt "statements"
  .node.Expr "final_operand"

ast.Decl:derive "VarDecl"
  .node.Expr "type"
  .node.Expr "expr"

ast.VarDecl:derive "BuiltinDecl"

ast.VarDecl:derive "FieldDecl"

ast.VarDecl:derive "ClosureArgDecl"

ast.Expr:derive "Tuple"
  .method.eachElem(function(self, f)
    self.elements:each(function(e)
      f(e)
    end)
  end)

ast.Expr:derive "NamedExpr"
  .node.Id "id"
  .node.Expr "expr"

ast.Tuple:derive "ValueTuple"
  .node.list.Expr "elements"

ast.Tuple:derive "DeclTuple"
  .node.list.Decl "elements"

ast.DeclTuple:derive "StructTuple"

ast.Decl:derive "UnboundClosureParam"

ast.Expr:derive "Closure"
  .prop(cmn.List) "idrefs"
  .node.DeclTuple "params"
  .node.Expr "body"

ast.Expr:derive "InstantiatedClosure"
  .node.DeclTuple "params"
  .node.Expr "body"

ast.Expr:derive "UnboundIdRef"

local BinOpKind = cmn.enum(cmn.Twine.new
  "Add"
  "Sub"
  "Mul"
  "Div"
  "Mod"
  "Equal"
  "NotEqual"
  "LessThan"
  "GreaterThan"
  "LessThanOrEqual"
  "GreaterThanOrEqual"
  "And"
  "Or"
  "Assign")

local binop_prio = 
{
  [BinOpKind.Add] = {6,6},
  [BinOpKind.Sub] = {6,6},
  [BinOpKind.Mul] = {7,7},
  [BinOpKind.Div] = {7,7},
  [BinOpKind.Mod] = {7,7},
  [BinOpKind.Equal] = {3,3},
  [BinOpKind.NotEqual] = {3,3},
  [BinOpKind.LessThan] = {3,3},
  [BinOpKind.GreaterThan] = {3,3},
  [BinOpKind.LessThanOrEqual] = {3,3},
  [BinOpKind.GreaterThanOrEqual] = {3,3},
  [BinOpKind.And] = {2,2},
  [BinOpKind.Or] = {1,1},
  [BinOpKind.Assign] = {0,0},
}

local setProperty = function(name, ...)
  cmn.List{...}:each(function(kind)
    kind[name] = true
  end)
end

setProperty("is_additive",
  BinOpKind.Add,
  BinOpKind.Sub)

setProperty("is_multiplicative",
  BinOpKind.Mul,
  BinOpKind.Div,
  BinOpKind.Mod)

setProperty("is_comparative",
  BinOpKind.Equal,
  BinOpKind.NotEqual,
  BinOpKind.LessThan,
  BinOpKind.GreaterThan,
  BinOpKind.LessThanOrEqual,
  BinOpKind.GreaterThanOrEqual)

setProperty("is_logical",
  BinOpKind.And,
  BinOpKind.Or)

BinOpKind.getPriority = function(self)
  local prio = binop_prio[self]
  return prio[1], prio[2]
end

local tok_to_binop_kind = 
{
  [Token.Kind.Plus] = BinOpKind.Add,
  [Token.Kind.Minus] = BinOpKind.Sub,
  [Token.Kind.Equal] = BinOpKind.Assign,
}

BinOpKind.fromTokenKind = function(tk)
  return tok_to_binop_kind[tk]
end

ast.Expr:derive "BinOp"
  .prop(BinOpKind) "kind"
  .node.Expr "lhs"
  .node.Expr "rhs"
  .writeValue(function(self, buf, parser)
    buf:put(tostring(self.kind))
  end)

ast.BinOp.Kind = BinOpKind

ast.Expr:derive "Call"
  .node.Expr "callee"
  .node.ValueTuple "args"

ast.Expr:derive "If"
  .node.Expr "cond"
  .node.Expr "body"
  .node.Expr "alt"

ast.Expr:derive "IsExpr"
  .node.Expr "lhs"
  .node.Expr "rhs"

ast.Expr:derive "Access"
  .node.Expr "lhs"
  .node.Id "rhs"


return ast
