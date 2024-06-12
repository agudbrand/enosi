local options = assert(lake.getOptions())

local List = require "list"

local mode = options.mode or "debug"
local builddir = lake.cwd().."/build/"..mode.."/"

options.registerCleaner(function()
	lake.rm(builddir, {recursive = true, force = options.force_clean})
end)

lake.mkdir(builddir, {make_parents = true})

local reports = assert(options.reports)
local recipes = assert(options.recipes)

local events = lake.target(builddir.."events")

local cflags = List
{
	options.getProjIncludeDirFlags "iro"
}

if mode == "debug" then
	cflags:push { "-O0", "-ggdb3", "-DLPP_DEBUG=1" }
else
	cflags:push "-O2"
end

if lake.os() == "Linux" then
	cflags:push "-DIRO_LINUX=1"
end

local lflags = List
{
	options.getProjLibDirFlags "luajit",
	options.getProjLibFlags "luajit"
}

local ofiles = List { reports.iro.objFiles }
 
lake.find("**/*.cpp"):each(function(cfile)
	local ofile = cfile:gsub("(.-)%.cpp", builddir.."%1.cpp.o")
	local dfile = ofile:gsub("(.-)%.o", "%1.d")

	lake.target(ofile)
		:dependsOn { cfile, options.this_file }
		:recipe(recipes.compiler(cfile, ofile, cflags))

	lake.target(dfile)
		:dependsOn { cfile }
		:recipe(recipes.depfile(cfile, dfile, ofile, cflags))

	events:dependsOn(ofile)

	ofiles:push(ofile)
end)

events:dependsOn(reports.iro.objFiles)

events:recipe(recipes.linker(ofiles, events, lflags))

