local log = require"logger"

local enosi = require "enosi"

local List = require "list"

--- A lake project
---
---@class Project
---@field name string
---@field path string
---@field log Logger
---@field cleaner table
---@field outputs table
---@field deps table[Project]
---@field artifacts Artifacts
local Project = {}
Project.__index = Project

Project.assert = function(self, cond, ...)
  if not cond then
    self.log:fatal(debug.traceback(), "\n", ...)
    os.exit(1)
  end
  return cond
end

Project.isTypeOf = function(x) return getmetatable(x) == Project end

--- Set the cleaner callback for this project. This should remove any 
--- files that the project generates. Note that this will be ran in the
--- working directory of the project AS LONG AS THIS FUNCTION IS CALLED 
--- FROM WITHIN THAT PROJECT'S project.lua!!
---
-- TODO(sushi) manually cache off what the working directory of projects are
--             on their object so that they dont have to call lake.cwd() and
--             so we dont have to worry about this little thing here.
---
---@param f function
Project.setCleaner = function(self, f)
  assert(not self.cleaner, self.name.." already set a cleaner!")
  self.cleaner = { lake.cwd(), f }
end

--- Declare that this project depends on some other project(s).
---
---@param ... string
Project.dependsOn = function(self, ...)
  List{...}:each(function(x)
    local proj = enosi.getProject(x)
    self:assert(proj,
      "no project with name '", x, "' has been registered with enosi.")
    self:assert(not self.deps[proj],
      "a dependency on ", proj.name, " was already declared")
    self.deps.tbl[proj] = true
    self.deps.list:push(proj)
  end)
end

local checkAbsolute = function(self, x)
  self:assert(x:sub(1,1) == '/',
    "path '", x, "' does not appear to be absolute")
end

Project.reportObjFile = function(self, ...)
  List{...}:each(function(ofile)
    checkAbsolute(self, ofile)
    self.artifacts.obj_files:push(ofile)
  end)
end

Project.reportExecutable = function(self, ...)
  List{...}:each(function(e)
    checkAbsolute(self, e)
    self.artifacts.executables:push(e)
  end)
end

Project.reportSharedLib = function(self, ...)
  List{...}:each(function(l)
    self.artifacts.shared_libs:push(l)
  end)
end


Project.reportStaticLib = function(self, ...)
  List{...}:each(function(l)
    self.artifacts.static_libs:push(l)
  end)
end

Project.reportLibDir = function(self, dir)
  self:assert(not self.artifacts.lib_dir,
    "only a single lib dir is supported for now")
  self.artifacts.lib_dir = dir
end

Project.reportIncludeDir = function(self, ...)
  List{...}:each(function(d)
    checkAbsolute(self, d)
    self.artifacts.include_dirs:push(d)
  end)
end

Project.reportDefine = function(self, ...)
  List{...}:each(function(d)
    self.artifacts.defines:push(d)
  end)
end

local getOSStaticLibName = function(s)
  if lake.os() == "Linux" then
    return "lib"..s..".a"
  else
    error("static lib name not setup for OS "..lake.os())
  end
end

--- Get a list of absolute paths to all the shared libraries reported by this 
--- project.
---@return List
Project.getLibs = function(self)
  local libdir = self.artifacts.lib_dir

  self:assert(libdir,
    "getProjLibs() called but this project does not define a lib dir!")

  return self.artifacts.shared_libs:map(function(e)
    return libdir..getOSStaticLibName(e)
  end)
end

-- Collect all static lib files reported by this project and its dependencies.
Project.collectStaticLibs = function(self)
  local libs = List{}

  self.deps.list:each(function(dep)
    libs:push(dep:collectStaticLibs())
  end)

  libs:push(self.artifacts.static_libs)

  return libs
end

-- Collect all shared lib files reported by this project and its dependencies.
Project.collectSharedLibs = function(self)
  local libs = List{}

  self.deps.list:each(function(dep)
    libs:push(dep:collectSharedLibs())
  end)

  libs:push(self.artifacts.shared_libs)

  return libs
end

--- Returns a list containing all of this project's obj files as well
--- as any emitted by projects it depends on.
Project.collectObjFiles = function(self)
  local files = List{}

  self.deps.list:each(function(dep)
    files:push(dep:collectObjFiles())
  end)

  files:push(self.artifacts.obj_files)

  return files
end

--- Returns a list containing this project's reorted libdir and any from its
--- dependencies.
Project.collectLibDirs = function(self)
  local dirs = List{}

  self.deps.list:each(function(dep)
    dirs:push(dep:collectLibDirs())
  end)

  dirs:push(self.artifacts.lib_dir)

  return dirs
end

--- Returns a list containing the include dirs of this project as well as 
--- those of its dependencies.
Project.collectIncludeDirs = function(self)
  local dirs = List{}

  self.deps.list:each(function(dep)
    dirs:push(dep:collectIncludeDirs())
  end)

  dirs:push(self.artifacts.include_dirs)

  return dirs
end

Project.collectDefines = function(self)
  local defs = List{}

  self.deps.list:each(function(dep)
    dep:collectDefines():each(function(def)
      defs:push(def)
    end)
  end)

  self.artifacts.defines:each(function(def)
    defs:push(def)
  end)

  return defs
end

--- An organized collection of outputs created by building a project that 
--- dependent modules may need to build correctly.
---@class Artifacts
---@field obj_files List
---@field executables List
---@field shared_libs List
---@field static_libs List
---@field lib_dir string
---@field include_dirs List
---@field defines List
local newArtifacts = function()
  return
  {
    obj_files = List{},
    executables = List{},
    shared_libs = List{},
    static_libs = List{},
    include_dirs = List{},
    defines = List{},
  }
end

---@return Project
Project.new = function(name, path)
  return setmetatable(
  {
    name = name,
    path = path,
    log = log(name, Verbosity.Notice),
    artifacts = newArtifacts(),
    deps = { list = List{}, tbl = {} }
  }, Project)
end

return Project
