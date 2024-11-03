local enosi = require "enosi"
local recipes = require "recipes"
local Driver = require "driver"
local proj = enosi.thisProject()

local mode = enosi.mode
local cwd = lake.cwd()

local builddir = cwd.."/build/"..mode.."/"
lake.mkdir(builddir, {make_parents=true})

proj:setCleaner(function()
  lake.rm(cwd.."/build", {recursive=true,force=true})
end)

proj:dependsOn("iro")

local lamu = lake.target(builddir.."lamu")

proj:reportExecutable(lamu.path)

local cpp_driver = Driver.Cpp.new()

cpp_driver.include_dirs:push { "src", proj:collectIncludeDirs() }

if mode == "debug" then
  cpp_driver.opt = "none"
  cpp_driver.debug_info = true
  proj:reportDefine { "LAMU_DEBUG", "1" }
else
  cpp_driver.opt = "speed"
end

cpp_driver.defines = proj:collectDefines()

lake.find("*.cpp"):each(function(cfile)
  local ofile = builddir..cfile..".o"
  local dfile = builddir..cfile..".d"
  cfile = cwd.."/"..cfile

  proj:reportObjFile(ofile)

  cpp_driver.input = cfile
  cpp_driver.output = ofile

  lake.target(ofile):dependsOn(cfile)
    :recipe(recipes.objFile(cpp_driver, proj))

  lake.target(dfile):dependsOn(cfile)
    :recipe(recipes.depfile(
      Driver.Depfile.fromCpp(cpp_driver),
      proj, ofile, dfile))
end)

lamu:dependsOn(proj:collectObjFiles())
lamu:dependsOn(proj:collectLuaObjFiles())

local link_driver = Driver.Linker.new()

local inputs = proj:collectObjFiles()

link_driver.static_libs = proj:collectStaticLibs()
link_driver.shared_libs = proj:collectSharedLibs()
link_driver.inputs = inputs
link_driver.libdirs = proj:collectLibDirs()
link_driver.output = lamu.path

lamu:recipe(recipes.linker(link_driver, proj))
