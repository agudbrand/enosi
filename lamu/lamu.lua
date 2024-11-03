local log = require "logger" ("lamu", Verbosity.Debug)
local LuaType = require "Type"
local List = require "list"
local co = require "coroutine"
local buffer = require "string.buffer"
local util = require "util"
local Twine = require "twine"
local errhandler = require "errhandler"
local pco = require "pco"
local cmn = require "common"
local Parser = require "parser"
local Lexer = require "lexer"

cmn.sethook()

local filename = "test.lamu"

local f = io.open(filename, "r")
if not f then
  cmn.fatal("failed to open ", filename)
end

local enum = function(elems)
  local o = LuaType.make()
  elems:eachWithIndex(function(elem,i)
    o[elem] = setmetatable({val=i},
      {
        __index = o,
        __tostring = function(self)
          return elem
        end
      })
  end)
  return o
end

local lexer = Lexer.new(filename, f:read("*a"))
local parser = Parser.new(lexer)

parser:start()
