local enosi = require "enosi"
local recipes = require "recipes"
local Driver = require "driver"
local proj = enosi.thisProject()

local mode = enosi.mode
local cwd = lake.cwd()

local builddir = cwd.."/build/"..mode.."/"
lake.mkdir(builddir, {make_parents=true})

proj:setCleaner(function()
  lake.rm(builddir, {recursive=true,force=true})
end)

proj:dependsOn("iro")

local elua = lake.target(builddir.."elua")

proj:reportExecutable(elua.path)

local cpp_driver = Driver.Cpp.new()

cpp_driver.include_dirs:push { "src", proj:collectIncludeDirs() }

if mode == "debug" then
  cpp_driver.opt = "none"
  cpp_driver.debug_info = true
  proj:reportDefine { "ELUA_DEBUG", "1" }
else
  cpp_driver.opt = "speed"
end

cpp_driver.defines = proj:collectDefines()

lake.find("src/**/*.cpp"):each(function(cfile)
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

elua:dependsOn(proj:collectObjFiles())

local link_driver = Driver.Linker.new()

local inputs = proj:collectObjFiles()

link_driver.static_libs = proj:collectStaticLibs()
link_driver.shared_libs = proj:collectSharedLibs()
link_driver.inputs = inputs
link_driver.libdirs = proj:collectLibDirs()
link_driver.output = elua.path

elua:recipe(recipes.linker(link_driver, proj))
