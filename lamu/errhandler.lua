local log = require "logger" ("lamu", Verbosity.Notice)

local function printer(...)
  log:notice(debug.traceback(), "\n")
  log:fatal(...)
  log:fatal("\n")
end

local function handler(obj)
  if type(obj) == "string" then
    printer(obj)
  elseif type(obj) == "function" then
    --- Idk.
    local result, message = pcall(obj, printer)
    if not result then
      print("error in function passed to error: \n", message)
    end
  else
    return obj
  end
end

return handler
