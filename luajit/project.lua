local enosi = require "enosi"
local proj = enosi.thisProject()

local List = require "list"

local cwd = lake.cwd()

local libdir = cwd.."/lib/"
local includedir = cwd.."/include/"

lake.mkdir(libdir)
lake.mkdir(includedir)

-- NOTE(sushi) this is needed just so we can create the proper target
local lib = enosi.getStaticLibName("luajit")

proj:reportIncludeDir(includedir)
proj:reportStaticLib("luajit")
proj:reportLibDir(libdir)

local luajit_makefiles = { "src/Makefile", "src/src/Makefile" }

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

lake.target(libdir..lib)
  :dependsOn(luajit_makefiles)
  :recipe(function()
    lake.chdir "src"
    lake.cmd { "make", "clean" }
    local result = lake.cmd(
      { "make", "-j" }, { onRead = io.write })

    if result ~= 0 then
      io.write(red, "building luajit failed\n", reset)
    end
  end)

-- ensure that relevant headers have been copied over to the include dir
local includes = List { "lua.h", "lauxlib.h", "lualib.h" }
local copied_includes = includes:map(function(e) return includedir..e end)

lake.targets(copied_includes)
	:dependsOn(luajit_makefiles)
	:recipe(function()
		includes:each(function(e)
			lake.copy(includedir..e, "./src/src/"..e)
		end)
	end)

proj:setCleaner(function()
	lake.chdir("src")
	lake.cmd(
		{"make", "clean"},
		{
			onStdout = io.write,
			onStderr = io.write,
		})
	lake.chdir("..")
	copied_includes:each(function(e)
		lake.rm(e)
	end)
	lake.rm(libdir..lib)
end)
