local mode = lake.clivars.mode or "debug"

local List = require "list"
local Twine = require "twine"

local result = {pcall(require, "lakeuser")}
local usercfg 

if result[1] then
	usercfg = result[2]
else
	usercfg = {}
end

lake.setMaxJobs(usercfg.max_jobs or 1)

lake.mkdir("bin")

local os = lake.os()
local cwd = lake.cwd()

local compiler = "clang++"
local linker = "clang++"

-- NOTE!! only general compiler flags that apply to all projects
--        can go here, projects may define their own flags in 
--        their modules
local compiler_flags = Twine.new
	"-std=c++20"
	"-Wno-switch"
	"-fcolor-diagnostics"
	"-fno-caret-diagnostics"
	"-Wno-#warnings"
	"-Wno-return-type-c-linkage"

if mode == "debug" then
	compiler_flags
		"-O0"
		"-ggdb3"
else
	compiler_flags
		"-O2"
end

local linker_flags = Twine.new
	"-lexplain"

local reset = "\027[0m"
local green = "\027[0;32m"
local blue  = "\027[0;34m"
local red   = "\027[0;31m"

-- converts a plain lib name to the operating system's name for the lib
local getOSStaticLibName
if os == "Linux" then
	getOSStaticLibName = function(x)
		return "lib"..x..".a"
	end
else
	error("getOSStaticLibName() has not been implemented for this OS.")
end

local outputCapture = function()
	local o = {}
	o.s = ""
	o.onStdout = function(s) o.s = o.s..s end
	o.onStderr = function(s) o.s = o.s..s end
	return o
end

local recipes = {}

recipes.linker = function(input, output, flags)
	assert(input and output, "recipes.linker passed a nil output or input")

    return function()
        -- make sure the output path exists
        local dir = tostring(output):match("(.*)/")
        lake.mkdir(dir, {make_parents = true})

		local capture = outputCapture()

        local start = lake.getMonotonicClock()
        local result = lake.cmd({ linker, input, linker_flags, flags or "", "-o", output }, capture)

        local time_took = (lake.getMonotonicClock() - start) / 1000000

        if result == 0 then
            io.write(blue, tostring(output), reset, " ", time_took, "s\n")
        else
            io.write(red, "compiling ", blue, tostring(output), red, " failed", reset, ":\n")
        end
		io.write(capture.s)
    end
end

recipes.compiler = function(input, output, flags)
	assert(input and output, "recipes.compiler passed a nil output or input")

    return function()
        local dir = tostring(output):match("(.*)/")
        lake.mkdir(dir, {make_parents = true})

		local capture = outputCapture()

        local start = lake.getMonotonicClock()
        local result = lake.cmd({ compiler, "-c", compiler_flags, flags or "", input, "-o", output }, capture)
        local time_took = (lake.getMonotonicClock() - start) / 1000000

        if result == 0 then
            io.write(green, input, reset, " -> ", blue, output, reset, " ", time_took, "s\n")
        else
            io.write(red, "compiling ", blue, output, red, " failed", reset, ":\n")
        end
		io.write(capture.s)
    end
end

recipes.staticLib = function(input, output, flags)
	assert(input and output, "recipes.staticLib pass a nil input or output")

	return function()
		local dir = tostring(output):match("(.*)/")
		lake.mkdir(dir, {make_parents = true})

		local capture = outputCapture()

		local start = lake.getMonotonicClock()
		local result = lake.cmd({ "ar", "rc", output, input }, capture)
		local time_took = (lake.getMonotonicClock() - start) / 1000000

		if result == 0 then
			io.write(blue, tostring(output), reset, " ", time_took, "s\n")
		else
			io.write(red, "compiling ", blue, output, red, " failed", reset, ":\n")
		end
		io.write(capture.s)
	end
end

recipes.depfile = function(c_file, d_file, o_file, flags, filter)
	assert(c_file and d_file and o_file, "recipes.depfile passed a nil file")

	-- attempt to load the depfile that may already exist
	local file = io.open(d_file, "r")
	lake.target(o_file):dependsOn(d_file)

	if file then
		local str = file:read("*a")
		for file in str:gmatch("%S+") do
			lake.target(o_file):dependsOn(file)
		end
	end

	return function()
		local dir = tostring(d_file):match("(.*)/")
		lake.mkdir(dir, {make_parents = true})

		local capture = outputCapture()

		local result = lake.cmd({ "clang++", c_file, compiler_flags, flags or "", "-MM", "-MG" }, capture)

		if result ~= 0 then
			error("failed to create dep file '"..d_file.."':\n"..capture.s)
		end

		local result = assert(lake.replace(capture.s, "\\\n", ""))

		local out = ""

		for f in result:gmatch("%S+") do
			if f:sub(-1) ~= ":" then
				if filter and filter(f) then
					goto continue
				end
				local canonical = lake.canonicalizePath(f)
				if not canonical then
					error("failed to canonicalize depfile path '"..f.."'! The file might not exist so I'll probably see this message when I'm working with generated files and so should try and handle this better then")
				end
				out = out..canonical.."\n"
			end
			::continue::
		end

		local f = io.open(d_file, "w")

		if not f then
			error("failed to open dep file for writing: '"..d_file.."'")
		end

		f:write(out)
		f:close()
	end
end

recipes.luaToObj = function(lfile, ofile)
	lake.mkdir(tostring(ofile):match("(.*)/"), {make_parents = true})

	local cmd = Twine.new
		"luajit" "-b"

	if mode == "debug" then
		cmd "-g"
	end

	return function()
		local capture = outputCapture()

		local start = lake.getMonotonicClock()
		local result = lake.cmd({cmd, lfile, ofile}, capture)
		local time_took = (lake.getMonotonicClock() - start) / 1000000

		if result == 0 then
			io.write(green, lfile, reset, " -> ", blue, ofile, reset, " ", time_took, "s\n")
		else
			io.write(red, "compiling ", blue, ofile, red, " failed", reset, ":\n")
		end

		io.write(capture.s)
	end
end

-- reports of different kinds of output files organized by project then type
-- eg. reports.iro.objFiles
local reports = {}

-- helper that returns a list of targets referencing the libs that 
-- a project outputs, so that dependencies may be created on them
local getProjLibs = function(projname)
	assert(reports[projname], "report.getProjLibs called on a project ("..projname..") that has not been imported yet!")
	return reports[projname].libs:map(function(e)
		return reports[projname].libDir[1]..getOSStaticLibName(e)
	end)
end

-- initialize a report object for 'projname'. 
-- this is passed to a lakemodule to enable them reporting different
-- kinds of outputs other projects may want to use.
-- a project is expected to report a string containing the absolute 
-- path of the output object. 
-- the build FAILS if a given path is not absolute.
local initReportObject = function(projname)
	local createReportFunction = function(objtype, require_absolute)
		if require_absolute == nil then
			require_absolute = true
		end
		reports[projname] = reports[projname] or {}
		reports[projname][objtype] = reports[projname][objtype] or List()
		local tbl = reports[projname][objtype]
		return function(output)
			assert(type(output) == "string", "reported output is not a string")
			if require_absolute then
				assert(output:sub(1,1) == "/", "reported output is not an absolute path")
			end
			tbl:push(output)
		end
	end

	return
	{
		objFile = createReportFunction "objFiles",
		executable = createReportFunction "executables",
		-- where a library project's include files are located.
		-- eg. iro would specify its root directory 
		includeDir = createReportFunction "includeDirs",

		-- Directory where libs provided by this library are located.
		-- A project must only report one lib directory!
		libDir = createReportFunction "libDir",

		-- Report libs that projects using this library should link against.
		-- These should be plain names of the lib, eg. report 'luajit' not
		-- 'libluajit.a'
		lib = createReportFunction("libs", false)
	}
end

-- collection of cleaners for each project
local cleaners = {}

-- generate function to give to 'projname' to report 
-- a function to perform a build clean.
local initCleanReportFunction = function(projname)
	return function(f)
		if cleaners[projname] then
			error("a cleaner has already been defined for "..projname, 2)
		end
		cleaners[projname] = {cwd, f}
	end
end

local imported_modules = {}

local import = function(projname)
	if imported_modules[projname] then
		error("attempt to import '"..projname.."' more than once.")
	end

	lake.import(projname.."/lakemodule.lua",
	{
		mode = mode,
		recipes = recipes,
		usercfg = usercfg,
		report = initReportObject(projname),
		reports = reports,
		registerCleaner = initCleanReportFunction(projname),
		assertImported = function(...)
			List{...}:each(function(name)
				assert(imported_modules[name], "project '"..projname.."' requires '"..name.."' to have been imported before it!")
			end)
		end,
		force_clean = true,
		getOSStaticLibName = getOSStaticLibName,
		getProjLibs = getProjLibs,
		getProjIncludeDirFlags = function(...)
			local out = List()
			List{...}:each(function(name)
				-- TODO(sushi) compiler specific include flagging, though idk if any compiler uses a syntax other than this
				reports[name].includeDirs:each(function(dir)
					out:push("-I"..dir)
				end)
			end)
			return out
		end,
		getProjLibFlags = function(...)
			local out = List()
			List{...}:each(function(name)
				reports[name].libs:each(function(lib)
					out:push("-l"..lib)
				end)
			end)
			return out
		end,
		getProjLibDirFlags = function(...)
			local out = List()
			List{...}:each(function(name)
				out:push("-L"..reports[name].libDir[1])
			end)
			return out
		end,
		this_file = cwd.."/"..projname.."/lakemodule.lua"
	})

	if not cleaners[projname] then
		io.write("warn: ", projname, " did not register a clean function\n")
	end

	imported_modules[projname] = true
end

import "llvm"
import "luajit"
import "iro"
import "lake"
-- import "lppclang"
import "lpp"
-- import "experimental/events"

-- clean build files of internal projects only, eg. not luajit and certainly not llvm
lake.action("clean", function()
	List{ "lpp", "iro", "lake", "lppclang" }:each(function(projname)
		local cleaner = cleaners[projname]
		if cleaner then
			io.write("cleaning ", projname, "\n")
			lake.chdir(cleaner[1])
			cleaner[2]()
			lake.chdir(cwd)
		end
	end)
end)

-- clean build files of internal and external projects, excluding llvm
lake.action("clean-all", function()
	List{ "lpp", "iro", "lake", "luajit", "lppclang" }:each(function(projname)
		local cleaner = cleaners[projname]
		if cleaner then
			io.write("cleaning ", projname, "\n")
			lake.chdir(cleaner[1])
			cleaner[2]()
			lake.chdir(cwd)
		end
	end)
end)

lake.action("clean-llvm", function()

end)
