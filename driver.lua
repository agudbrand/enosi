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
---@class Driver
local Driver = {}

local makeDriver = function(name)
  Driver[name] = {}
  Driver[name].__index = Driver[name]
  return Driver[name]
end

--- Driver for C++ compilers. Compiles a single C++ file into 
--- an object file.
---
---@class Driver.Cpp
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
--- Force all symbols exposed to the dynamic table by default.
--- Default is false.
---@field export_all boolean
local Cpp = makeDriver "Cpp"
Driver.Cpp = Cpp

---@return Driver.Cpp
Cpp.new = function()
  return setmetatable(
  {
    defines = List{},
    include_dirs = List{},
    libs = List{},
  }, Cpp)
end

--- Generates the IO independent flags since these are now needed
--- by both Lpp and Cpp
local getCppIOIndependentFlags = function(self, proj)
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

    return cmdBuilder(
      "-Wno-#warnings",
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
      not self.export_all and "-fvisibility=hidden" or "")
  end
end

Cpp.makeCmd = function(self, proj)
  local cmd
  if "clang++" == enosi.c.compiler then
    cmd = cmdBuilder(
      "clang++",
      "-c",
      self.input,
      "-o", self.output,
      getCppIOIndependentFlags(self, proj))
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
Driver.Depfile = Depfile

---@return Depfile
Depfile.new = function()
  return setmetatable(
  {
    defines = List{},
    include_dirs = List{},
  }, Depfile)
end

--- Creates a Depfile driver from an existing Cpp driver.
---@param cpp Driver.Cpp
---@return Depfile
Depfile.fromCpp = function(cpp)
  return setmetatable(
  {
    defines = cpp.defines,
    include_dirs = cpp.include_dirs,
    input = cpp.input,
  }, Depfile)
end

string.startsWith = function(self, s)
  return self:sub(1, #s) == s
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
        if f:sub(-1) == ":" or
           f == "\\"
        then
          goto continue
        end

        if not f:startsWith "generated" then
          local canonical = lake.canonicalizePath(f)
          proj:assert(canonical,
            "while generating depfile for "..self.input..":\n"..
            "failed to canonicalize depfile path '"..f)
          out:put(canonical, "\n")
        end
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
---@class Driver.Linker
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
Driver.Linker = Linker

---@return Driver.Linker
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
      -- Expose all symbols so that lua obj file stuff is exposed and so that
      -- things marked EXPORT_DYNAMIC are as well.
      "-Wl,-E",
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
Driver.LuaObj = LuaObj

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

--- Driver for running standalone lua scripts using elua.
--- This assumes release elua has been built and exists in enosi's bin folder.
--- A driver is not reeeally necessary but doing so for consistency.
---
---@class LuaScript
--- The lua script to run.
---@field input string
local LuaScript = makeDriver "LuaScript"
Driver.LuaScript = LuaScript

---@return LuaScript
LuaScript.new = function()
  return setmetatable({}, LuaScript)
end

LuaScript.makeCmd = function(self, proj)
  local cmd = List{}

  proj:assert(self.input,
    "LuaScript.makeCmd called on a driver with a nil input")

  return cmdBuilder(
    enosi.cwd.."/bin/elua",
    self.input)
end

--- Driver for compiling lpp files.
---
---@class Driver.Lpp
--- The file to compile.
---@field input string
--- The file that will be output.
---@field output string
--- Require dirs.
---@field requires List
--- The Cpp driver that will be used to build the resulting file.
---@field cpp Driver.Cpp
local Lpp = makeDriver "Lpp"
Driver.Lpp = Lpp

---@return Driver.Lpp
Lpp.new = function()
  return setmetatable(
  {
    requires = List{}
  }, Lpp)
end

Lpp.makeCmd = function(self, proj)
  local cmd = List{}

  proj:assert(self.input and self.output, 
    "Lpp.makeCmd called on a driver with a nil input or output")

  proj:assert(self.cpp,
    "Lpp.makeCmd called on a driver with a nil Cpp driver")

  local cppargs = getCppIOIndependentFlags(self.cpp, proj)

  local cargs = "--cargs="

  lake.flatten(cppargs):each(function(arg)
    cargs = cargs..arg..","
  end)

  local requires = List{}
  self.requires:each(function(require)
    requires:push("-R")
    requires:push(require)
  end)

  local includes = List{}
  self.cpp.include_dirs:each(function(include)
    includes:push("-I")
    requires:push(include)
  end)

  return cmdBuilder(
    enosi.cwd.."/bin/lpp",
    self.input,
    "-o", self.output,
    cargs,
    requires)
end


--- Driver for generating a depfile using lpp.
---
---@class Driver.LppDepFile
--- The file to compile.
---@field input string
--- The file that will be output.
---@field output string
--- Require dirs.
---@field requires List
--- The Cpp driver that will be used to build the resulting file.
---@field cpp Driver.Cpp
local LppDepFile = makeDriver "LppDepFile"
Driver.LppDepFile = LppDepFile

LppDepFile.new = function()
  return setmetatable(
  {
    requires = List{}
  }, LppDepFile)
end

LppDepFile.makeCmd = function(self, proj)
  local cmd = List{}

  proj:assert(self.input and self.output, 
    "LppDepFile.makeCmd called on a driver with a nil input or output")

  proj:assert(self.cpp,
    "LppDepFile.makeCmd called on a driver with a nil Cpp driver")

  local cppargs = getCppIOIndependentFlags(self.cpp, proj)

  local cargs = "--cargs="

  lake.flatten(cppargs):each(function(arg)
    cargs = cargs..arg..","
  end)

  local requires = List{}
  self.requires:each(function(require)
    requires:push("-R")
    requires:push(require)
  end)

  local includes = List{}
  self.cpp.include_dirs:each(function(include)
    includes:push("-I")
    requires:push(include)
  end)

  return cmdBuilder(
    enosi.cwd.."/bin/lpp",
    self.input,
    cargs,
    requires,
    "-D",
    self.output)
end

return Driver
