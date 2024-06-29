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
  print(debug.traceback())
  io.write(red, "failed to build ", blue, output, reset, ":\n")
end


-- * ==========================================================================
-- *   Recipes
-- * ==========================================================================


---@param driver Linker
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
---@param driver Cpp
---@param proj Project
recipes.objFile = function(driver, proj)
  assert(driver and proj, "recipes.objFile passed a nil driver or proj")

  local cmd = driver:makeCmd(proj)
  local input = proj:assert(driver.input,
    "recipes.objFile() called with a driver that has a nil input")
  local output = proj:assert(driver.output,
    "recipes.objFile() called with a driver that has a nil output")

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

--- Generate a dependency file from a C file.
---@param driver Depfile
---@param proj Project
---@param ofile string
---@param dfile string
recipes.depfile = function(driver, proj, ofile, dfile)
  assert(driver and proj, "recipes.depfile passed a nil driver or proj")

  local cmd, processFunc = driver:makeCmd(proj)
  local cfile = driver.input

  lake.target(ofile):dependsOn(dfile)

  -- Try to load the depfile that may already exist
  local existing_file = io.open(dfile, "r")

  if existing_file then
    local str = existing_file:read("*a")
    for file in str:gmatch("%S+") do
      lake.target(ofile):dependsOn(file)
    end
  end

  return function()
    ensureDirExists(dfile)
    local capture = outputCapture()
    local result = lake.cmd(cmd, capture)

    if result ~= 0 then
      error("failed to create dep file '"..dfile.."':\n"..capture.s:get())
    end

    local cap = capture.s:get()
    proj.log:error(cap, "\n")

    local out = processFunc(cap)

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

return recipes
