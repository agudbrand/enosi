local options = assert(lake.getOptions())

local List = require "list"

local report = assert(options.report)

local libdir = lake.cwd().."/lib/"
local includedir = lake.cwd().."/include/"

local lib

local os = lake.os()

-- resolve the name of the lib that luajit will output 
-- this should NOT be passed to the lakefile! its just a special 
-- case where we need to know what the actual filename luajit outputs is
if os == "Linux" then
	lib = "libluajit.a"
else
	error("luajit lakemodule has not been setup for compilation on this OS yet.")
end

report.lib("luajit")
report.libDir(libdir)

local luajit_makefiles = { "src/Makefile", "src/src/Makefile" }

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

-- build luajit's lib via its makefile
lake.target(libdir..lib)
	-- the only thing I'll ever change with luajit (for now) is the options in its Makefiles
	:dependsOn(luajit_makefiles)
	:recipe(function()
		local start = lake.getMonotonicClock()
		lake.chdir("src")
		local result = lake.cmd( { "make", "-j"..tostring(lake.getMaxJobs()) },
		{
			onStdout = function(s)
				io.write(s)
			end,

			onStderr = function(s)
				io.write(s)
			end
		}) -- TODO(sushi) add a way to get the max jobs setting so it can be passed here
		if result ~= 0 then
			io.write(red, "making luajit failed: ", reset, "\n")
			error("luajit failed")
		end
		lake.chdir("..")
		lake.copy(libdir..lib, "src/src/"..lib)
		local time_took = (lake.getMonotonicClock() - start) / 1000000
		io.write(blue, libdir..lib, reset, " ", time_took, "\n")
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

options.registerCleaner(function()
	lake.chdir("src")
	lake.cmd({"make", "clean"},
	{
		onStdout = function(s)
			io.write(s)
		end,

		onStderr = function(s)
			io.write(s)
		end
	})
	lake.chdir("..")
	copied_includes:each(function(e)
		lake.rm(e)
	end)
	lake.rm(libdir..lib)
end)
