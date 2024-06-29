local enosi = require "enosi"
local proj = enosi.thisProject()

local cwd = lake.cwd()

local builddir = cwd.."/build/"
lake.mkdir(builddir, {make_parents=true})

local lib = "notcurses-core"

proj:reportLibDir(builddir)
proj:reportIncludeDir(cwd.."/src/include/")
proj:reportStaticLib(lib)

-- Note these are specified for dependent projects to know what to link
-- against. This does not affect how this project is built.
proj:reportSharedLib("deflate", "unistring", "ncurses")

local CMakeCache = lake.target(builddir.."/CMakeCache.txt")

lake.target(builddir..enosi.getStaticLibName(lib))
    :dependsOn(CMakeCache)
    :recipe(function()
      lake.chdir(builddir)

      local result = lake.cmd(
        { "make", "-j" }, {onRead = io.write})

      if result ~= 0 then
        io.write("building notcurses failed\n")
      end

      lake.chdir(cwd)
    end)

CMakeCache
    :dependsOn(proj.path)
    :recipe(function()
      lake.chdir(builddir)

      local result = lake.cmd(
        { "cmake", "-G", "Unix Makefiles", "../src",
            "-DUSE_PANDOC=off",
            "-DUSE_MULTIMEDIA=none",
            "-DBUILD_EXECUTABLES=off",
            "-DBUILD_TESTING=off" },
        { onRead = io.write })

      if result ~= 0 then
        io.write("cmake configuration for notcurses failed\n")
        return
      end

      lake.chdir(cwd)
      lake.touch(CMakeCache.path)
    end)
