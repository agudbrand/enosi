local options = assert(lake.getOptions())

local List = require "list"
local Twine = require "twine"

local report = assert(options.report)
local reports = assert(options.reports)

local libs = Twine.new
  "notcurses"
  "notcurses-core"

local cwd = lake.cwd()

local usercfg = options.usercfg
usercfg.notcurses = usercfg.notcurses or {}

local builddir = cwd.."/build/"
lake.mkdir(builddir, {make_parents = true})

report.libDir(builddir)
report.includeDir(builddir.."include/")

local libsfull = libs:map(function(l)
  return builddir.."/"..options.getOSStaticLibName(l)
end)

local CMakeCache = lake.target(builddir.."/CMakeCache.txt")

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

reports.notcurses.libsTarget = lake.targets(libsfull)
  :dependsOn(CMakeCache)
  :recipe(function()
    lake.chdir(builddir)

    local result = lake.cmd(
      { "make", "-j12" }, { onRead = io.write })

    if result ~= 0 then
      io.write(red, "building notcurses failed", reset, "\n")
    end

    lake.chdir(cwd)
  end)

CMakeCache
  :dependsOn(options.this_file)
  :recipe(function()
    lake.chdir(builddir)

    local args = List.new
    {
      "-DUSE_PANDOC=off",
      "-DUSE_MULTIMEDIA=none",
      "-DBUILD_EXECUTABLES=off",
      "-DBUILD_TESTING=off",
    }

    local result = lake.cmd(
      { "cmake", "-G", "Unix Makefiles", "../src", args },
      {onRead = io.write})

      if result ~= 0 then
        io.write(red, "cmake configure for notcurses failed", reset, "\n")
        return
      end

      lake.chdir(cwd)
      lake.touch(CMakeCache.path)
  end)
