local cmn = require "common"
local co = require "coroutine"
local diag = require "diag"
local Diag = diag.Diag
local ast = require "ast"
local Token = require "token"
local log = require "lamulog"
local errh = require "errhandler"
local Sema = require "sema"
local util = require "util"

--- Parses tokens created by the Lexer.
---@class lamu.Parser
--- The Lexer in use.
---@field lex lamu.Lexer
--- The current Token.
---@field curt Token
---@field backtracked number?
local Parser = cmn.LuaType.make()

Parser.done = {}

---@return Parser
Parser.new = function(lex)
  local o = {}
  o.lex = lex
  o.co = cmn.pco(Parser.parseTopLevelStmts, errh)
  o.depth = 0
  o.sema = Sema.new(o)
  o.closure_stack = cmn.List{}
  o.resume = function(self, ...)
    local result = {co.resume(self.co, self, ...)}
    if not result[1] then
      -- Some sort of internal error must have occured that we didn't handle
      -- via 'fatal' (since that should exit the program entirely).
      -- So we just pass the error object to the normal error handler.
      error(result[2])
    end

    -- Determine what to do based on the returned object.
    result = result[2]

    if result == Parser.done then
      -- We're done!
      return Parser.done
    elseif result:is(Diag) then
      -- We're encountering an unhandled diagnostic, so just ask it to 
      -- emit whatever it needs to say.
      result:emit(self)
    end
  end
  o.start = function(self)
    self:nextToken()
    return self:resume()
  end
  return setmetatable(o, Parser)
end

Parser.printIndent = function(self)
  for _=1,self.depth do
    log:info " "
  end
end

Parser.incIndent = function(self)
  self.depth = self.depth + 1
end

Parser.decIndent = function(self)
  self.depth = self.depth - 1
end

Parser.printLine = function(self, ...)
  if false then
    self:printIndent()
    log:info(...)
    log:info("\n")
  end
end

Parser.pushClosureContext = function(self)
  self.closure_stack:push
  {
    idrefs = cmn.List{}
  }
end

Parser.popClosureContext = function(self)
  return self.closure_stack:pop()
end

Parser.currentClosure = function(self)
  return self.closure_stack:last()
end

---@return Token
Parser.nextToken = function(self)
  if self.backtracked then
    self.backtracked = self.curt.next_significant
    if self.backtracked == #self.lex.tokens then
      self.backtracked = nil
      self.curt = self.lex.tokens[#self.lex.tokens]
    else
      self.curt = self.lex.tokens[self.backtracked]
    end
    self:printLine("| ", self.curt, " (backtracked)")
    return self.curt
  else
    local curt = self.curt
    local count = #self.lex.tokens
    while true do
      self.curt = self.lex:nextToken()
      if self.curt.kind ~= Token.Kind.Whitespace and
         self.curt.kind ~= Token.Kind.Comment
      then
        if curt then
          curt.next_significant = #self.lex.tokens
        end
        self.curt.prev_significant = count
        self:printLine("| ", self.curt)
        return self.curt
      end
    end
  end
end

-- Moves backwards by n tokens in the token stream.
Parser.backtrack = function(self, n)
  local walk = 
    self.backtracked and self.lex.tokens[self.backtracked] or 
    self.curt
  n = n or 1
  local idx = 0
  for i=1,n do
    idx = walk.prev_significant
    walk = self.lex.tokens[idx]
  end
  self.backtracked = idx
  self.curt = self.lex.tokens[self.backtracked]
  self:printLine("- ", self.curt)
end

Parser.backtrackTo = function(self, n)
  self.backtracked = n
  self.curt = self.lex.tokens[self.backtracked]
  self:printLine("-- ", self.curt)
end

Parser.at = function(self, tk)
  return self.curt.kind == tk
end

--- Yields the parser with the provided object.
Parser.yield = function(self, obj)
  return co.yield(obj)
end

--- Checks if the current Token is of kind 'tk'. If it is the token
--- stream is advanced and the Token is returned. Otherwise returns 
--- nil.
Parser.check = function(self, tk)
  if self.curt.kind == tk then
    local out = self.curt
    self:nextToken()
    return out
  end
end

Parser.skipToMatchingPair = function(self)
  local pairs = 
  {
    [Token.Kind.LBrace] = Token.Kind.RBrace,
    [Token.Kind.LParen] = Token.Kind.RParen,
  }

  local lpair = self.curt.kind
  local rpair = pairs[self.curt.kind]
  if rpair then
    local nesting = 1
    while true do
      local curt = self:nextToken()
      if curt.kind == Token.Kind.Eof then
        break
      elseif curt.kind == lpair then
        nesting = nesting + 1
      elseif curt.kind == rpair then
        nesting = nesting - 1
        if nesting == 0 then
          break
        end
      end
    end
  end
end

--- Helper for tracking stages of parsing and easily injecting code
--- around them.
Parser.stage = setmetatable({},
{
  __newindex = function(self, key, value)
    if type(value) ~= "function" then
      error("Parser.stage must be a function")
    end
    Parser[key] = function(parser, ...)
      parser:printLine("> ", key)
      parser:incIndent()
      local result = value(parser, ...)
      parser:decIndent()
      parser:printLine("< ", key, " ", result)
      return result
    end
  end
})

Parser.stage.parseTopLevelStmts = function(self)
  local tlstmts = cmn.List{}
  while true do
    if self:check(Token.Kind.Eof) then
      break
    end

    local stmt = self:parseStmt()
    if stmt then
      tlstmts:push(stmt)
      stmt:dump(self)
      self.sema:on(stmt)
    end
  end
  tlstmts:each(function(stmt)
    stmt:dump(self)
  end)
  return Parser.done
end

Parser.stage.parseStmt = function(self)
  if self:check(Token.Kind.Semicolon) then
    -- Skip empty statements.
    return
  end

  return (self:parseExprOrDeclStmt())
end

Parser.stage.parseExprOrDeclStmt = function(self)
  local id = self:check(Token.Kind.Identifier)
  if id then
    if self:check(Token.Kind.Colon) then
      return (self:parseDecl(id))
    end
    self:backtrack()
  end
  return (ast.ExprStmt { expr = self:parseExpr() })
end

Parser.stage.parseDecl = function(self, id)
  -- <id> ':' <object> [';']
  
  if self:at(Token.Kind.Equal) then
    return (self:parseVarDecl(id))
  elseif self:at(Token.Kind.Struct) then
    return (self:parseStructDecl(id))
  else
    return (self:parseVarDecl(id, self:parseTypeExpr()))
  end
end

Parser.stage.parseStructDecl = function(self, id)
  local start = self.curt
  self:nextToken()
  return ast.StructDecl
  {
    start = start,
    id = ast.Id { start = id },
    body = self:parseDeclTuple()
  }
end

Parser.stage.parseVarDecl = function(self, id, type)
  -- <id> ':' <type> 
  -- <id> ':' <type> '=' <expr>
  -- <id> ':' '=' <expr>
  -- 'id' and 'type' are always parsed outside of this function.
  
  local expr
  if self:at(Token.Kind.Equal) then
    self:nextToken()
    expr = self:parseExpr()
  end

  local decl = 
    ast.VarDecl
    {
      id = ast.Id { start = id },
      type = type,
      expr = expr
    }

  self.sema.scope:recordDecl(self.sema, decl)
  return decl
end

Parser.stage.parseTypeExpr = function(self)
  local unioned = cmn.List{}
  while true do
    local id = self:check(Token.Kind.Identifier)
    if not id then
      self:yield(diag.expected_value_or_type(self.curt))
    end
    unioned:push(
      ast.IdRef
      {
        start = id,
        decl = self.sema:requireSymbol(self.lex, id)
      })

    if not self:check(Token.Kind.VerticalBar) then
      break
    end
  end

  if 1 == #unioned then
    return unioned[1]
  else
    return 
      (ast.Union
      {
        options = unioned
      })
  end
end

Parser.stage.parseExpr = function(self)
  if self:at(Token.Kind.If) then
    return (self:parseIf())
  else
    return (self:parseSubExpr(0))
  end
end

Parser.stage.parseIf = function(self)
  if not self:check(Token.Kind.If) then
    self:yield(diag.expected_if(self.curt))
  end

  self.sema:enterScope()

  local cond = self:parseExpr()
  
  if self:check(Token.Kind.Is) then
    local rhs = self:parseTypeExpr()
    cond = ast.IsExpr
    {
      lhs = cond,
      rhs = rhs,
    }
  end

  if not self:at(Token.Kind.LBrace) then
    if not self:check(Token.Kind.Then) then
      self:yield(diag.expected_then_or_block(self.curt))
    end
  end

  local body = self:parseExpr()
  local alt
  if self:check(Token.Kind.Else) then
    alt = self:parseExpr()
  end
    
  local node = 
    ast.If
    {
      cond=cond,
      body=body,
      alt=alt,
    }

  self.sema:leaveScope(node)

  return node
end

Parser.stage.parseBlock = function(self)
  local start = self.curt
  local stop
  if not self:check(Token.Kind.LBrace) then
    self:yield(diag.expected_block(self.curt))
  end

  self.sema:enterScope()

  local stmts = cmn.List{}
  local final_operand

  while true do
    stop = self.curt
    if self:check(Token.Kind.RBrace) then
      break
    end
    local expr_or_decl = self:parseExprOrDeclStmt()
    if self:check(Token.Kind.Semicolon) then
      if expr_or_decl:is(ast.Expr) then
        stmts:push(ast.ExprStmt { expr = expr_or_decl })
      else
        stmts:push(expr_or_decl)
      end
      stop = self.curt
      if self:check(Token.Kind.RBrace) then
        break   
      end
    else
      final_operand = expr_or_decl.expr
      stop = self.curt
      if not self:check(Token.Kind.RBrace) then
        self:yield(diag.expected_rbrace_or_semicolon(self.curt))
      end
      break
    end
  end

  util.dumpValue(final_operand, 2)

  local block = 
    ast.Block
    {
      start = start,
      stop = stop,
      statements = stmts,
      final_operand = final_operand,
    }

  self.sema:leaveScope(block)

  return block
end

-- Parses an expression potentially preceeded by <id> ':'.
-- This will cause something like 
--   <id> ':' <type> '=' <expr>
-- to be parsed into 
--   (NamedValue
--     Id
--     (BinOp.Assign
--       <type>
--       <expr>))
-- so do not use this where actual declarations are expected.
-- This is used in call argument tuples to allow named arguments.
Parser.stage.parsePotentiallyNamedExpr = function(self)
  local id = self:check(Token.Kind.Identifier)
  if id then
    if self:at(Token.Kind.Colon) then
      self:nextToken()
      return 
        (ast.NamedExpr
        { 
          id = ast.Id { start = id },
          expr = self:parseExpr(),
        })
    else
      self:backtrack()
    end
  end
  return (self:parseExpr())
end

Parser.stage.parseNamedExpr = function(self)
  local id = self:check(Token.Kind.Identifier)
  if id then
    if self:check(Token.Kind.Colon) then
      return 
        (ast.NamedExpr
        {
          id = ast.Id { start = id },
          expr = self:parseExpr(),
        })
    end
  end
  self:yield(diag.expected_named_expr(self.curt))
end

Parser.stage.parseSubExpr = function(self, limit)
  local simple_expr = self:parseSimpleExpr()

  local bor = simple_expr

  while true do
    local bk = ast.BinOp.Kind.fromTokenKind(self.curt.kind)
    if not bk then
      break
    end
    local pleft, pright = bk:getPriority()
    if pleft < limit then
      break
    end
    self:nextToken()
    local subexpr = self:parseSubExpr(pright)
    bor = ast.BinOp
    {
      kind = bk,
      lhs = bor,
      rhs = subexpr
    }
  end

  return bor
end

Parser.stage.parseSimpleExpr = function(self)
  if self.curt.kind.is_literal then
    local literal = ast.Literal { start = self.curt }
    self:nextToken()
    return literal
  else
    return (self:parsePrimaryExpr())
  end
end

Parser.stage.parsePrimaryExpr = function(self)
  local primary
  local primary_switch =
  {
  [Token.Kind.Identifier] = function()
    local decl = 
      self.sema.scope:findDecl(
        self.sema,
        self.lex:getRaw(self.curt))
    if not decl then
      self:yield(diag.unknown_identifier(self.curt))
    end
    if decl:is(ast.UnboundClosureParam) then
      primary = 
        ast.UnboundIdRef
        {
          start = self.curt,
        }
    else
      primary = 
        ast.IdRef 
        { 
          start = self.curt,
          decl = decl,
        }
    end
    self:nextToken()
  end,
  [Token.Kind.LParen] = function()
    primary = self:parseTupleOrClosureOrParenthesizedExpr()
  end,
  [Token.Kind.LBrace] = function()
    primary = self:parseBlock()
  end,
  [Token.Kind.Struct] = function()
    self.sema:enterScope()
    primary = self:parseStructTuple()
    self.sema:leaveScope(primary)
  end
  }
  local primary_case = primary_switch[self.curt.kind]
  if not primary_case then
    self:yield(diag.expected_expr(self.curt))
  end
  primary_case()

  local suffix = primary
  local suffix_switch =
  {
    [Token.Kind.LParen] = function()
      -- Function call.
      local tuple = self:parseValueTuple()
      suffix = ast.Call
      {
        callee = suffix,
        args = tuple,
      }
    end,
    [Token.Kind.Period] = function()
      -- Field access.
      self:nextToken()
      local id = self:check(Token.Kind.Identifier)
      if not id then
        self:yield(diag.expected_id(self.curt))
      end
      suffix = ast.Access
      {
        lhs = suffix,
        rhs = ast.Id { start = id },
      }
    end,
  }
  
  while true do
    local suffix_case = suffix_switch[self.curt.kind]
    if suffix_case then
      suffix_case()
    else 
      break
    end
  end

  return suffix
end

-- Determines what kind of tuple we've come against and parses it.
Parser.stage.parseTuple = function(self)
  if not self:check(Token.Kind.LParen) then
    self:yield(diag.expected_tuple(self.curt))
  end

  local is_decl = false

  if self:check(Token.Kind.Identifier) then
    if self:at(Token.Kind.Colon) then
      is_decl = true
    end
    self:backtrack()
  end

  self:backtrack()

  if is_decl then
    return (self:parseDeclTuple())
  else
    return (self:parseValueTuple())
  end
end

Parser.stage.parseDeclTuple = function(self)
  if not self:at(Token.Kind.LParen) then
    self:yield(diag.expected_tuple(self.curt, "decl"))
  end
  return (self:parseTupleImpl(
    ast.DeclTuple,
    function()
      local id = self:check(Token.Kind.Identifier)
      if not id then 
        self:yield(diag.expected_decl(self.curt))
      end
      return (self:parseDecl(id))
    end))
end

Parser.stage.parseStructTuple = function(self)
  if not self:at(Token.Kind.Struct) then
    self:yield(diag.expected_struct(self.curt))
  end
  local start = self.curt
  self:nextToken()
  local tuple = self:parseTupleImpl(ast.StructTuple,
    function()
      local id = self:check(Token.Kind.Identifier)
      if not id or not self:check(Token.Kind.Colon) then 
        self:yield(diag.expected_decl(self.curt))
      end
      return (self:parseDecl(id))
    end)
  tuple.start = start
  self.sema:on(tuple)
  return tuple
end

Parser.stage.parseValueTuple = function(self)
  if not self:at(Token.Kind.LParen) then
    self:yield(diag.expected_tuple(self.curt, "value"))
  end
  local found_named = false
  return (self:parseTupleImpl(
    ast.ValueTuple,
    function()
      if not found_named then
        local result = self:parsePotentiallyNamedExpr()
        if result:is(ast.NamedExpr) then
          found_named = true
        end
        return result
      else
        return (self:parseNamedExpr())
      end
    end))
end

Parser.stage.parseTupleImpl = function(self, TupleAST, parseElem)
  local start = self.curt
  local stop
  self:nextToken()

  if self:at(Token.Kind.RParen) then
    stop = self.curt
    self:nextToken()
    return 
      (TupleAST
      {
        start = start,
        stop = stop,
      })
  end

  local elems = cmn.List{}

  while true do 
    elems:push(parseElem())

    if self:check(Token.Kind.Semicolon) then
      -- Continue to parse more elements.
    elseif self:check(Token.Kind.RParen) then
      stop = self.curt
      break
    else
      -- Invalid tuple.
      self:yield(diag.tuple_expected_semi_or_rparen(self.curt))
    end
  end

  return 
    (TupleAST
    { 
      start = start, 
      stop = stop,
      elements = elems 
    })
end

Parser.stage.parseClosure = function(self)
  if not self:check(Token.Kind.LParen) then
    self:yield(diag.expected_closure(self.curt))
  end

  self.sema:enterScope()

  local params = cmn.List{}

  while true do
    if self:check(Token.Kind.RParen) then
      break  
    end

    local id = self:check(Token.Kind.Identifier)
    if id then
      if self:check(Token.Kind.Semicolon) or 
         self:at(Token.Kind.RParen) 
      then
        local param = 
          ast.UnboundClosureParam
          {
            id = ast.Id { start = id }
          }
        self.sema.scope:recordDecl(self.sema, param)
        params:push(param)
      else
        params:push(self:parseDecl(id))
      end
    else
      self:yield(diag.expected_closure_param(self.curt))
    end
  end

  if not self:check(Token.Kind.ThickArrow) then
    self:yield(diag.expected_closure_arrow(self.curt))
  end

  self:pushClosureContext()

  local expr = self:parseExpr()

  local ctx = self:popClosureContext()

  local closure = ast.Closure
    {
      idrefs = ctx.idrefs,
      params = ast.DeclTuple
      {
        elements = params
      },
      body = expr
    }

  self.sema:leaveScope(closure)

  return closure
end

Parser.stage.parseTupleOrClosureOrParenthesizedExpr = function(self)
  -- Perform a deep lookahead to determine if we are parsing a closure 
  -- or not.
  local start = self.curt
  local rollback = self.backtracked or #self.lex.tokens
  self:skipToMatchingPair()
  if self:at(Token.Kind.Eof) then
    self:yield(diag.unexpected_eof(start))
  end
  self:nextToken()

  if self:at(Token.Kind.ThickArrow) then
    self:backtrackTo(rollback)
    return (self:parseClosure())
  end

  local tuple = self:parseTuple()
  if tuple:is(ast.ValueTuple) then
    if 1 == #tuple.elements then
      -- Don't unwrap if the single expression is an assignment, as
      -- its possible that it's a tuple being used to initialize a var
      -- of some struct type.
      local elem = tuple.elements[1]
      if not elem:is(ast.BinOp) or elem.kind ~= ast.BinOp.Kind.Assign then
        return elem
      end
    end
  end
  return tuple
end

return Parser
