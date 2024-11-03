---
--- Stuff that is commonly used or doesn't really have a place anywhere else.
---

local LuaType = require "Type"
local co = require "coroutine"
local errh = require "errhandler"

local common = {}

--- Common libraries.
common.buffer = require "string.buffer"
common.LuaType = require "Type"
common.List = require "list"
common.Twine = require "twine"

--- Emits the given message and then exits the program.
common.fatal = function(...)
  local args = {...}
  error(function(printer)
    printer(unpack(args))
    os.exit(1)
  end)
end

common.type = function(x)
  return type(x)
end

--- Helper for hooking an error handler into coroutines.
---
--- The way this is done sucks but oh well.
common.pco = function(f)
  assert(f)
  return co.create(function(...)
    common.sethook()
    local result = {xpcall(function(...) 
      common.sethook()
      return f(...)
    end, errh, ...)}
    if not result[1] then
      errh(result[2])
    else
      return unpack(result, 2)
    end
  end)
end

--- Creates an 'enum' with a unique Type.
common.enum = function(elems)
  local o = LuaType.make()
  elems:eachWithIndex(function(elem,i)
    o[elem] = setmetatable({val=i},
      {
        __index = o,
        __tostring = function()
          return elem
        end
      })
  end)
  return o
end

--- Returns a table that calls 'f' when indexed.
common.indexer = function(f)
  return setmetatable({}, { __index = f })
end

--- Returns a table that calls 'fi' when indexed and 'fc' when called.
common.indexcaller = function(fi, fc)
  return setmetatable({}, { __index=fi, __call=fc })
end

common.sethook = function()
  local inst = {}
  if false then
    debug.sethook(function(event, line)
      local i = debug.getinfo(2)
      local s = i.short_src
      if s ~= "./parser.lua" then
        return
      end
      local f = i.name
      local id = s..":"..line
      if not inst[id] then 
        inst[id] = 1 
      else
        inst[id] = inst[id] + 1
      end
      if f then 
        print(id.." "..f.." "..inst[id])
      else
        print(id.." "..inst[id])
      end
    end, "l")
  end
end

return common
