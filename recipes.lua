--- Collection of common Lake recipes used to build various types of files.

local enosi = require "enosi"
local buffer = require "string.buffer"
local driver = require "driver"
local recipes = {}


-- * ==========================================================================
-- *   Helpers
-- * ==========================================================================


local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

local ensureDirExists = function(output)
  local dir = tostring(output):match "(.*)/"
  if dir then
    lake.mkdir(dir, {make_parents = true})
  end
end

local outputCapture = function()
  local o = {}
  o.s = buffer.new()
  o.onRead = function(s) o.s:put(s) end
  return o
end

local timedCmd = function(args, capture)
  local start = lake.getMonotonicClock()
  local result = lake.cmd(args, capture)
  return result, (lake.getMonotonicClock() - start) / 1000000
end

local localOutput = function(x)
  return tostring(x):sub(#enosi.cwd+2)
end

local writeSuccessOnlyOutput = function(output, time_took)
  io.write(blue, localOutput(output), reset, " ", time_took, "s\n")
end

local writeSuccessInputToOutput = function(input, output, time_took)
  io.write(
    green, input, reset, " -> ", blue, localOutput(output), reset, " ",
    time_took, "s\n")
end

local writeFailure = function(output)
  io.write(red, "failed to build ", blue, output, reset, ":\n")
end


-- * ==========================================================================
-- *   Recipes
-- * ==========================================================================


---@param driver Driver.Linker
---@param proj Project
recipes.linker = function(driver, proj)
  assert(driver and proj, "recipes.executable passed a nil input or output")

  -- Cache off command and output as the caller to this will likely change 
  -- parts of it.
  local cmd = driver:makeCmd(proj)
  local output = proj:assert(driver.output,
    "recipes.executable() passed a driver with a nil output")

  return function()
    ensureDirExists(driver.output)
    local capture = outputCapture()
    local result, time_took = timedCmd(cmd, capture)

    if result == 0 then
      writeSuccessOnlyOutput(output, time_took)
    else
      writeFailure(output)
    end

    io.write(capture.s:get())
  end
end

--- Compile a C source file into an object file.
---@param driver Driver.Cpp
---@param proj Project
recipes.objFile = function(driver, proj)
  assert(driver and proj, "recipes.objFile passed a nil driver or proj")

  local cmd = driver:makeCmd(proj)
  local input = proj:assert(driver.input,
    "recipes.objFile() called with a driver that has a nil input")
  local output = proj:assert(driver.output,
    "recipes.objFile() called with a driver that has a nil output")

  local printCmd = function()
    local out = ""
    lake.flatten(cmd):each(function(arg)
      out = out..arg.." "
    end)
    print(out)
  end

  -- printCmd()

  return function()
    ensureDirExists(output)
    local capture = outputCapture()
    local result, time_took = timedCmd(cmd, capture)

    if result == 0 then
      writeSuccessInputToOutput(input, output, time_took)
    else
      writeFailure(output)
    end

    io.write(capture.s:get())
  end
end

local makeDepsFromDepFile = function(path, ofile)
  local existing_file = io.open(path, "r")

  if existing_file then
    local str = existing_file:read("*a")
    for file in str:gmatch("%S+") do
      lake.target(ofile):dependsOn(file)
    end
  end
end

--- Run lpp.
---@param driver Driver.Lpp
---@param proj Project
recipes.lpp = function(driver, proj)
  proj:assert(driver,
    "recipes.lpp passed a nil driver")

  local cmd = driver:makeCmd(proj)

  local input = driver.input
  local output = driver.output

  local printCmd = function()
    local out = ""
    lake.flatten(cmd):each(function(arg)
      out = out..arg.." "
    end)
    print(out)
  end

  -- printCmd()

  if driver.depfile then
    makeDepsFromDepFile(driver.depfile, driver.cpp.output)
    makeDepsFromDepFile(driver.depfile, driver.cpp.input)
  end

  lake.target(output):dependsOn(enosi.cwd.."/bin/lpp")

  return function()
    ensureDirExists(output)
    local capture = outputCapture()
    local result, time_took = timedCmd(cmd, capture)

    if result == 0 then
      writeSuccessInputToOutput(input, output, time_took)
    else
      writeFailure(output)
    end

    io.write(capture.s:get())
  end
end

--- Generate a dependency file from an lpp file.
---@param driver Driver.LppDepFile
---@param proj Project
---@param ofile string
---@param dfile string
recipes.depfileLpp = function(driver, proj, ofile, cfile, dfile)
  assert(driver and proj, "recipes.depfileLpp passed a nil driver or proj")

  local cmd = driver:makeCmd(proj)

  local printCmd = function()
    local out = ""
    lake.flatten(cmd):each(function(arg)
      out = out..arg.." "
    end)
    print(out)
  end

  -- printCmd()

  lake.target(ofile):dependsOn(dfile)

  makeDepsFromDepFile(dfile, ofile)
  makeDepsFromDepFile(dfile, cfile)

  return function()
    ensureDirExists(dfile)
    local capture = outputCapture()
    local result = lake.cmd(cmd, capture)

    if result ~= 0 then
      writeFailure(dfile)
    end

    io.write(capture.s:get())
  end
end

--- Generate a dependency file from a C file.
---@param driver Depfile
---@param proj Project
---@param ofile string
---@param dfile string
recipes.depfile = function(driver, proj, ofile, dfile)
  assert(driver and proj, "recipes.depfile passed a nil driver or proj")

  local cmd, processFunc = driver:makeCmd(proj)

  lake.target(ofile):dependsOn(dfile)

  -- Try to load the depfile that may already exist
  makeDepsFromDepFile(dfile, ofile)

  return function()
    ensureDirExists(dfile)
    local capture = outputCapture()
    local result = lake.cmd(cmd, capture)

    if result ~= 0 then
      error("failed to create dep file '"..dfile.."':\n"..capture.s:get())
    end

    local out = processFunc(capture.s:get())

    local fout = io.open(dfile, "w")
    proj:assert(fout, "failed to open dep file ", dfile, " for writing.")

    fout:write(out)
    fout:close()
  end
end

--- Compile an obj file from a lua script.
---@param driver LuaObj
---@param proj Project
recipes.luaObjFile = function(driver, proj)
  assert(driver and proj, "recipes.luaObjFile passed a nil driver or proj")

  local cmd = driver:makeCmd(proj)
  local input = driver.input
  local output = driver.output

  return function()
    ensureDirExists(driver.output)
    local capture = outputCapture()
    local result, time_took = timedCmd(cmd, capture)

    if result == 0 then
      writeSuccessInputToOutput(input, output, time_took)
    else
      writeFailure(output)
    end

    io.write(capture.s:get())
  end
end

--- Run a standalone lua script.
---@param driver LuaScript
---@param proj Project
---@param output string | List the output(s) of this script invocation
recipes.luaScript = function(driver, proj, output)
  proj:assert(driver and proj and output,
    "recipes.luaScript passed a nil driver, proj, or output")

  local cmd = driver:makeCmd(proj)
  local input = driver.input
  local output = output

  return function()
    ensureDirExists(output)
    local capture = outputCapture()
    local result, time_took = timedCmd(cmd, capture)

    if result == 0 then
      -- TODO(sushi) handle multiple outputs eventually!
      writeSuccessInputToOutput(input, output, time_took)
    else
      writeFailure(output)
    end

    io.write(capture.s:get())
  end
end

return recipes
