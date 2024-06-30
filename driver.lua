--- 
--- Helpers for generating proper build tool commands based on generalized
--- sets of options.
---
--- This abstracts common options between different compilers and such 
--- so that enosi projects may avoid directly specifying compiler commands.
---
--- Named after the clang Driver.
---

local enosi = require "enosi"
local List = require "list"
local buffer = require "string.buffer"

--- Helper for generating a command which sanitizes falsy values and 
--- empty args.
---
--- An empty arg can cause weird behavior in some programs, particularly 
--- bear, the program I use to generate my compile_commands.json.
local cmdBuilder = function(...)
  local out = List{}

  List{...}:each(function(arg)
    if arg then
      if type(arg) ~= "string" or #arg ~= 0 then
        out:push(arg)
      end
    end
  end)

  return out
end

--- Collection of drivers of various tools.
local driver = {}

local makeDriver = function(name)
  driver[name] = {}
  driver[name].__index = driver[name]
  return driver[name]
end

--- Driver for C++ compilers. Compiles a single C++ file into 
--- an object file.
---
---@class Cpp
--- The C++ std to use.
---@field std string
--- The optimization to use. Default is 'none'.
--- May be one of:
---   none
---   size
---   speed
---@field opt string
--- List of preprocessor defines provided in the form:
---   { name, value }
---@field defines List
--- If debug info should be emitted.
---@field debug_info boolean
--- Directories to search for includes.
---@field include_dirs List
--- Path to the C++ file to compile.
---@field input string
--- Path to the object file output.
---@field output string
--- Disable building with C++'s builtin RTTI
---@field nortti boolean
local Cpp = makeDriver "Cpp"
driver.Cpp = Cpp

---@return Cpp
Cpp.new = function()
  return setmetatable(
  {
    defines = List{},
    include_dirs = List{},
    libs = List{},
  }, Cpp)
end

Cpp.makeCmd = function(self, proj)
  local cmd
  if "clang++" == enosi.c.compiler then
    local optmap =
    {
      none  = "-O0",
      size  = "-Os",
      speed = "-O2"
    }
    local opt = proj:assert(optmap[self.opt or "none"],
      "invalid optimization level specified ", self.opt)

    local debug_flag = ""
    if self.debug_info then
      debug_flag = "-ggdb3"
    end

    cmd = cmdBuilder(
      "clang++",
      "-c",
      "-Wno-#warnings",
      self.input,
      "-std="..(self.std or "c++20"),
      self.nortti and "-fno-rtti" or "",
      opt,
      enosi.c.cflags,
      self.defines:map(function(d)
        if d[2] then
          return "-D"..d[1].."="..d[2]
        else
          return "-D"..d[1]
        end
      end),
      lake.flatten(self.include_dirs):map(function(d)
        return "-I"..d
      end),
      debug_flag,
      -- NOTE(sushi) currently all projects are assumed to be able to export
      --             dynamic symbols via iro's EXPORT_DYNAMIC and on clang
      --             defaulting this to hidden is required for that to work
      --             properly with executables.
      "-fvisibility=hidden",
      "-o",
      self.output)
  else
    error("Cpp driver not setup for compiler "..enosi.c.compiler)
  end
  return cmd
end

--- Driver for generating dependencies of a C++ file.
--- These must generate a command for a program that generates some 
--- output specifying all the deps of a C++ file and a function that
--- takes that output and transforms it into enosi's depfile format
--- which is just a newline delimited list of absolute paths to files 
--- that the given C++ file depends on.
---
---@class Depfile
--- List of preprocessor defines provided in the form:
---   { name, value }
---@field defines List
--- Directories to search for includes.
---@field include_dirs List
--- Path to the C++ file.
---@field input string
local Depfile = makeDriver "Depfile"
driver.Depfile = Depfile

---@return Depfile
Depfile.new = function()
  return setmetatable(
  {
    defines = List{},
    include_dirs = List{},
  }, Depfile)
end

--- Creates a Depfile driver from an existing Cpp driver.
---@param cpp Cpp
---@return Depfile
Depfile.fromCpp = function(cpp)
  return setmetatable(
  {
    defines = cpp.defines,
    include_dirs = cpp.include_dirs,
    input = cpp.input,
  }, Depfile)
end

---@param proj Project
Depfile.makeCmd = function(self, proj)
  proj:assert(self.input, "Depfile.makeCmd called on a driver with no input")
  local cmd
  local processFunc = nil
  if "clang++" == enosi.c.compiler then
    cmd = cmdBuilder(
      "clang++",
      self.input,
      self.defines:map(function(d)
        if d[2] then
          return "-D"..d[1].."="..d[2]
        else
          return "-D"..d[1]
        end
      end),
      lake.flatten(self.include_dirs):map(function(d)
        return "-I"..d
      end),
      "-MM",
      "-MG")

    processFunc = function(file)
      local out = buffer.new()

      for f in file:gmatch("%S+") do
        if f:sub(-1) == ":" or f == "\\" then
          goto continue
        end

        local canonical = lake.canonicalizePath(f)
          proj:assert(canonical,
            "while generating depfile for "..self.input..":\n"..
            "failed to canonicalize depfile path '"..f..
            "'! The file might not exist so I'll probably see this message "..
            "when I'm working with generated files and so should try and "..
            "handle this better then")
        out:put(canonical, "\n")
        ::continue::
      end

      return out:get()
    end
  else
    error("Depfile driver not setup for compiler "..enosi.c.compiler)
  end

  return cmd, processFunc
end

--- Driver for linking object files and libraries into an executable or 
--- shared library.
---
---@class Linker
--- Libraries to link against. CURRENTLY these are wrapped in a group
--- on Linux as I am still too lazy to figure out what the proper link order
--- is for llvm BUT when I get to Windows I'll need to figure that out UGH
---@field shared_libs List
--- Static libs to link against. This is primarily useful when a library 
--- outputs both static and shared libs under the same name and the shared 
--- lib is preferred (at least on linux, where -l<libname> prefers the 
--- static lib).
---@field static_libs List
--- List of directories to search for libs in.
---@field libdirs List
--- Input files for the linker.
---@field inputs List
--- If this is meant to be an executable or shared lib.
---@field shared_lib boolean
--- The output file path
---@field output string
local Linker = makeDriver "Linker"
driver.Linker = Linker

---@return Linker
Linker.new = function()
  return setmetatable(
  {
    libs = List{},
    inputs = List{},
    libdirs = List{},
  }, Linker)
end

Linker.makeCmd = function(self, proj)
  local cmd
  if "clang++" == enosi.c.linker then
    cmd = cmdBuilder(
      "clang++",
      "-fuse-ld=mold", -- TODO(sushi) remove eventually 
      self.inputs,
      "-flto",
      lake.flatten(self.libdirs):map(function(dir)
        return "-L"..dir
      end),
      "-Wl,--start-group",
      lake.flatten(self.shared_libs):map(function(lib)
        return "-l"..lib
      end),
      lake.flatten(self.static_libs):map(function(lib)
        return "-l:lib"..lib..".a"
      end),
      "-Wl,--end-group",
      self.shared_lib and "-shared" or "",
      "-o",
      self.output)
  else
    error("Linker driver not setup for linker "..enosi.c.linker)
  end

  return cmd
end

--- Driver for creating an obj file from a lua file for statically linking 
--- lua modules into executables.
---
---@class LuaObj
--- Input lua file.
---@field input string
--- Output obj file.
---@field output string
--- Whether to leave debug info (default ON)
---@field debug_info boolean
local LuaObj = makeDriver "LuaObj"
driver.LuaObj = LuaObj

---@return LuaObj
LuaObj.new = function()
  return setmetatable(
  {
    debug_info = true
  }, LuaObj)
end

LuaObj.makeCmd = function(self, proj)
  local cmd = List{}

  proj:assert(self.input and self.output,
    "LuaObj.makeCmd called on a driver with a nil input or output")

  return cmdBuilder(
    "luajit",
    "-b",
    self.debug_info and "-g",
    self.input,
    self.output)
end

return driver
