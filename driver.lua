--- 
--- Helpers for generating proper build tool commands based on generalized
--- sets of options.
---
--- This abstracts common options between different compilers and such 
--- so that enosi projects may avoid directly specifying compiler commands.
---
--- Named after the clang Driver, though this does the opposite of what it
--- does (I think).
---

local List = require "list"
local buffer = require "string.buffer" ---@alias buffer table

--- Helper for generating a command which sanitizes falsy values and 
--- empty args.
---
--- An empty arg can cause weird behavior in some programs, particularly 
--- bear, the program I use to generate my compile_commands.json.
---@param ... any
---@return List
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

---@param name string
---@return Driver
local makeDriver = function(name)
  Driver[name] = {}
  Driver[name].__index = Driver[name]
  return Driver[name]
end

--- Driver for C++ compilers. Compiles a single C++ file into 
--- an object file.
---
---@class Driver.Cpp: Driver
--- The name of the binary to use.
---@field binary string
--- If debug info should be emitted. Defaults to false.
---@field debug_info boolean
--- List of preprocessor defines provided in the form:
---   { name1, name2, value2 }
---@field defines List
--- Force all symbols exposed to the dynamic table by default.
--- Defaults to false.
---@field export_all boolean
--- Table of lists of binary-specific flags in the form:
---   { ["binary1"]: { "-flag1", "-flag2" }, ["binary2"]: { "-flag3" } }
---@field flags table
--- Directories to search for includes.
---@field include_dirs List
--- Path to the C++ file.
---@field input string
--- Disable building with C++'s builtin RTTI. Defaults to false.
---@field nortti boolean
--- The optimization to use. Default is 'none'.
--- May be one of:
---   none
---   size
---   speed
---@field opt string
--- Path to the object file output.
---@field output string
--- The C++ std to use.
---@field std string
Driver.Cpp = makeDriver "Cpp"

---@return Driver.Cpp
Driver.Cpp.new = function()
  return setmetatable(
  {
    defines = List{},
    flags = {},
    include_dirs = List{},
  }, Driver.Cpp)
end

--- Generates the IO independent flags since these are now needed
--- by both Lpp and Cpp
---@param self Driver.Cpp
---@param proj Project
---@return List
local getCppIOIndependentFlags = function(self, proj)
  if "clang++" == self.binary then
    local optmap =
    {
      none  = "-O0",
      size  = "-Os",
      speed = "-O2"
    }
    local opt = proj:assert(optmap[self.opt or "none"],
      "invalid optimization level specified ", self.opt)

    return cmdBuilder(
      "-Wno-#warnings",
      "-fdiagnostics-absolute-paths",
      "-std="..(self.std or "c++20"),
      self.nortti and "-fno-rtti" or "",
      opt,
      self.debug_info and "-ggdb3" or "",
      self.flags[self.binary] or "",
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
      -- NOTE(sushi) currently all projects are assumed to be able to export
      --             dynamic symbols via iro's EXPORT_DYNAMIC and on clang
      --             defaulting this to hidden is required for that to work
      --             properly with executables.
      "-fpatchable-function-entry=16",
      not self.export_all and "-fvisibility=hidden" or "")
  elseif "cl" == self.binary then
    local optmap =
    {
      none  = "-O0",
      size  = "-O1",
      speed = "-O2"
    }
    local opt = proj:assert(optmap[self.opt or "none"],
      "invalid optimization level specified ", self.opt)

    return cmdBuilder(
      "-utf-8",
      "-nologo",
      "-FC", -- full paths in diagnostics
      "-std:"..(self.std or "c++20"),
      self.nortti and "-GR-" or "-GR",
      opt,
      self.debug_info and List{ "-Z7", "-Od" } or "",
      self.flags[self.binary] or "",
      self.defines:map(function(d)
        if d[2] then
          return "-D"..d[1].."="..d[2]
        else
          return "-D"..d[1]
        end
      end),
      lake.flatten(self.include_dirs):map(function(d)
        return "-I"..d
      end))
  else
    return List{}
  end
end

---@param self Driver.Cpp
---@param proj Project
---@return List
Driver.Cpp.makeCmd = function(self, proj)
  local cmd
  if "clang++" == self.binary then
    cmd = cmdBuilder(
      "clang++",
      "-c", self.input,
      "-o", self.output,
      getCppIOIndependentFlags(self, proj))
  elseif "cl" == self.binary then
    cmd = cmdBuilder(
      "cl",
      "-c", self.input,
      "-Fo:", self.output,
      getCppIOIndependentFlags(self, proj))
  else
    error("Cpp driver not setup for compiler "..self.binary)
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
---@class Driver.Depfile: Driver
--- The name of the binary to use.
---@field binary string
--- List of preprocessor defines provided in the form:
---   { name1, name2, value2 }
---@field defines List
--- Table of lists of binary-specific flags in the form:
---   { ["binary1"]: { "-flag1", "-flag2" }, ["binary2"]: { "-flag3" } }
---@field flags table
--- Directories to search for includes.
---@field include_dirs List
--- Path to the C++ file.
---@field input string
Driver.Depfile = makeDriver "Depfile"

---@return Driver.Depfile
Driver.Depfile.new = function()
  return setmetatable(
  {
    defines = List{},
    flags = {},
    include_dirs = List{},
  }, Driver.Depfile)
end

--- Creates a Depfile driver from an existing Cpp driver.
---@param cpp Driver.Cpp
---@return Driver.Depfile
Driver.Depfile.fromCpp = function(cpp)
  return setmetatable(
  {
    defines = cpp.defines,
    include_dirs = cpp.include_dirs,
    input = cpp.input,
  }, Driver.Depfile)
end

---@param self Driver.Depfile
---@param proj Project
---@return List, fun(file:string):string
Driver.Depfile.makeCmd = function(self, proj)
  proj:assert(self.input, "Depfile.makeCmd called on a driver with nil input")

  local cmd
  local processFunc = nil
  if "clang++" == self.binary then
    cmd = cmdBuilder(
      "clang++",
      self.input,
      self.flags[self.binary] or "",
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

        if f:sub(1, #"generated") ~= "generated" then
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
  elseif "cl" == self.binary then
    cmd = cmdBuilder(
      "cl",
      self.input,
      self.flags[self.binary] or "",
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
      "-sourceDependencies-")

      processFunc = function(file)
        local out = buffer.new()
        local includes_array = file:match('"Includes":%s*(%b[])')
        for include in includes_array:gmatch('"(.-)"') do
          out:put(include, "\n")
        end
        return out:get()
      end
  else
    error("Depfile driver not setup for dependency finder "..self.binary)
  end

  return cmd, processFunc
end


--- Driver for linking object files and libraries into an executable or 
--- shared library.
---
---@class Driver.Linker: Driver
--- The name of the binary to use.
---@field binary string
--- If debug info should be emitted.
---@field debug_info boolean
--- Force all symbols exposed to the dynamic table by default.
--- Default is false.
---@field export_all boolean
--- Table of lists of binary-specific flags in the form:
---   { ["binary1"]: { "-flag1", "-flag2" }, ["binary2"]: { "-flag3" } }
---@field flags table
--- Input files for the linker.
---@field inputs List
--- List of directories to search for libs in.
---@field libdirs List
--- The optimization to use. Default is 'none'.
--- May be one of:
---   none
---   size
---   speed
---@field opt string
--- The output file path.
---@field output string
--- Path to consider loading shared libraries from hardcoded into the 
--- executable (at least on Linux, I don't know if Windows has an option
--- for this yet). Used to avoid needing to add a project's build dir or 
--- whatever in the LD_LIBRARY_PATH env var. We should find a better solution
--- for this, as it will be using absolute paths to point the exe at the 
--- correct 
---@field rpath string
--- If this is meant to be an executable or shared lib.
---@field shared_lib boolean
--- Shared libraries to link against. CURRENTLY these are wrapped in a group
--- on Linux as I am still too lazy to figure out what the proper link order
--- is for llvm BUT when I get to Windows I'll need to figure that out UGH
---@field shared_libs List
--- Static libraries to link against. This is primarily useful when a library
--- outputs both static and shared libs under the same name and the shared
--- lib is preferred (at least on linux, where -l<libname> prefers the
--- static lib).
---@field static_libs List
Driver.Linker = makeDriver "Linker"

---@return Driver.Linker
Driver.Linker.new = function()
  return setmetatable(
  {
    flags = {},
    libs = List{},
    libdirs = List{},
  }, Driver.Linker)
end

---@param self Driver.Linker
---@param proj Project
---@return List
Driver.Linker.makeCmd = function(self, proj)
  proj:assert(self.inputs,
  "Linker.makeCmd called on a driver with nil inputs")
  proj:assert(self.output,
  "Linker.makeCmd called on a driver with nil output")
  
  local cmd
  if "mold" == self.binary then
    cmd = cmdBuilder(
      "mold",
      self.inputs,
      -- Expose all symbols so that lua obj file stuff is exposed and so that
      -- things marked EXPORT_DYNAMIC are as well.
      "-E",
      self.shared_lib and "-shared" or "",
      self.flags[self.binary] or "",
      lake.flatten(self.libdirs):map(function(dir)
        return "-L"..dir
      end),
      "--start-group",
      lake.flatten(self.shared_libs):map(function(lib)
        return "-l"..lib
      end),
      lake.flatten(self.static_libs):map(function(lib)
        return "-l:lib"..lib..".a"
      end),
      "--end-group",
      -- Tell the executable to search its directory for libs to load.
      "-rpath,$ORIGIN",
      "-o",
      self.output)
  elseif "link" == self.binary then
    local optmap =
    {
      none  = "",
      size  = "-OPT:REF",
      speed = "-OPT:REF"
    }
    local opt = proj:assert(optmap[self.opt or "none"],
      "invalid optimization level specified ", self.opt)

    local def = ""
    if self.export_all then
      --TODO
    end

    cmd = cmdBuilder(
      "link",
      self.inputs,
      "-nologo",
      opt,
      def,
      self.debug_info and "-DEBUG" or "",
      self.shared_lib and "-DLL" or "",
      self.flags[self.binary] or "",
      lake.flatten(self.libdirs):map(function(dir)
        return "-libpath:"..dir
      end),
      lake.flatten(self.shared_libs):map(function(lib)
        return "-l"..lib
      end),
      lake.flatten(self.static_libs):map(function(lib)
        return "-l:lib"..lib..".a"
      end),
      "-OUT:"..self.output)
  else
    error("Linker driver not setup for linker "..self.binary)
  end

  return cmd
end


--- Driver for creating an obj file from a lua file for statically linking 
--- lua modules into executables.
---
---@class Driver.LuaObj: Driver
--- Whether to leave debug info. Defaults to true.
---@field debug_info boolean
--- Input lua file.
---@field input string
--- Output obj file.
---@field output string
Driver.LuaObj = makeDriver "LuaObj"

---@return Driver.LuaObj
Driver.LuaObj.new = function()
  return setmetatable(
  {
    debug_info = true
  }, Driver.LuaObj)
end

---@param self Driver.LuaObj
---@param proj Project
---@return List
Driver.LuaObj.makeCmd = function(self, proj)
  proj:assert(self.input,
    "LuaObj.makeCmd called on a driver with nil input")
  proj:assert(self.output,
    "LuaObj.makeCmd called on a driver with nil output")

  return cmdBuilder(
    "luajit",
    "-b",
    self.debug_info and "-g" or "",
    self.input,
    self.output)
end


--- Driver for running standalone lua scripts using elua.
---
---@class Driver.LuaScript: Driver
--- The path to the elua binary to use. Defaults to '<cwd>/bin/elua'.
---@field binary string
--- The lua script to run.
---@field input string
Driver.LuaScript = makeDriver "LuaScript"

---@return Driver.LuaScript
Driver.LuaScript.new = function()
  return setmetatable({}, Driver.LuaScript)
end

---@param self Driver.LuaScript
---@param proj Project
---@return List
Driver.LuaScript.makeCmd = function(self, proj)
  proj:assert(self.input,
    "LuaScript.makeCmd called on a driver with a nil input")

  local binary = self.binary or lake.cwd().."/bin/elua"

  return cmdBuilder(
    binary,
    self.input)
end


--- Driver for compiling lpp files using lpp.
---
---@class Driver.Lpp: Driver
--- The path to the lpp binary to use. Defaults to '<cwd>/bin/lpp'.
---@field binary string
--- The Cpp driver that will be used to build the resulting file.
---@field cpp Driver.Cpp
--- The file to compile.
---@field input string
--- The file that will be output.
---@field output string
--- Require dirs.
---@field requires List
--- Optional path to output a metafile to.
---@field metafile string
Driver.Lpp = makeDriver "Lpp"

---@return Driver.Lpp
Driver.Lpp.new = function()
  return setmetatable(
  {
    requires = List{}
  }, Driver.Lpp)
end

---@param self Driver.Lpp
---@param proj Project
---@return List
Driver.Lpp.makeCmd = function(self, proj)
  proj:assert(self.input,
    "Lpp.makeCmd called on a driver with a nil input")
  proj:assert(self.output,
    "Lpp.makeCmd called on a driver with a nil output")
  proj:assert(self.cpp,
    "Lpp.makeCmd called on a driver with a nil Cpp driver")

  local binary = self.binary or lake.cwd().."/bin/lpp"

  --- Used inside ECS to output UI widget use files.
  local cpp_path = "--cpp-path="..self.output

  local metafile
  if self.metafile then
    metafile = { "-om", self.metafile }
  end

  local cargs = "--cargs="
  local cppargs = getCppIOIndependentFlags(self.cpp, proj)
  lake.flatten(cppargs):each(function(arg)
    cargs = cargs..arg..","
  end)

  local requires = List{}
  self.requires:each(function(require)
    requires:push("-R")
    requires:push(require)
  end)
  self.cpp.include_dirs:each(function(include)
    requires:push(include)
  end)

  return cmdBuilder(
    binary,
    self.input,
    "-o", self.output,
    -- "--print-meta",
    cpp_path,
    metafile,
    cargs,
    requires)
end


--- Driver for generating a depfile using lpp.
---
---@class Driver.LppDepFile: Driver
--- The path to the lpp binary to use. Defaults to '<cwd>/bin/lpp'.
---@field binary string
--- The Cpp driver that will be used to build the resulting file.
---@field cpp Driver.Cpp
--- The file to compile.
---@field input string
--- The file that will be output.
---@field output string
--- Require dirs.
---@field requires List
Driver.LppDepFile = makeDriver "LppDepFile"

---@return Driver.LppDepFile
Driver.LppDepFile.new = function()
  return setmetatable(
  {
    requires = List{}
  }, Driver.LppDepFile)
end

---@param self Driver.LppDepFile
---@param proj Project
---@return List
Driver.LppDepFile.makeCmd = function(self, proj)
  proj:assert(self.input,
    "LppDepFile.makeCmd called on a driver with a nil input")
  proj:assert(self.output,
    "LppDepFile.makeCmd called on a driver with a nil input")
  proj:assert(self.cpp,
    "LppDepFile.makeCmd called on a driver with a nil Cpp driver")

  local binary = self.binary or lake.cwd().."/bin/lpp"

  local cargs = "--cargs="
  local cppargs = getCppIOIndependentFlags(self.cpp, proj)
  lake.flatten(cppargs):each(function(arg)
    cargs = cargs..arg..","
  end)

  local requires = List{}
  self.requires:each(function(require)
    requires:push("-R")
    requires:push(require)
  end)
  self.cpp.include_dirs:each(function(include)
    requires:push(include)
  end)

  return cmdBuilder(
    binary,
    self.input,
    cargs,
    requires,
    -- "--print-meta",
    "-D",
    self.output)
end


-- Formats the input library name into a static lib name for the target OS.
---@param lib string
---@return string
Driver.getStaticLibName = function(lib)
  if lake.os() == "Linux" then
    return "lib"..lib..".a"
  elseif lake.os() == "Windows" then
    return lib..".lib"
  else
    error("unhandled OS")
  end
end

-- Formats the input library name into a shared lib name for the target OS.
---@param lib string
---@return string
Driver.getSharedLibName = function(lib)
  if lake.os() == "Linux" then
    return "lib"..lib..".so"
  elseif lake.os() == "Windows" then
    return lib..".dll"
  else
    error("unhandled OS")
  end
end

return Driver
