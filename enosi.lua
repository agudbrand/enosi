--- Manager of projects and settings applying to all of them.
---@class Enosi
--- Collection of settings related to the C language.
---@field c table
--- The current build mode
---@field mode string
local enosi = {}

local List = require "list"
local Twine = require "twine"

local os = lake.os()
local cwd = lake.cwd()

enosi.cwd = cwd

package.path = package.path..";"..cwd.."/?.lua"

-- Try to load the user config and set various settings based on it.
local usercfg = {pcall(require, "user")}

if usercfg[1] then
  usercfg = usercfg[2]
else
  usercfg = {}
end

enosi.mode = usercfg.mode or "debug"

lake.setMaxJobs(usercfg.max_jobs or 1)

lake.mkdir "bin"

-- TODO(sushi) supporting other compilers and linkers and such 
--             and deciding them based on the current operating system.
--             Outside of the scope of what I'm doing at the moment.
enosi.c = {}
enosi.c.compiler = "clang++"
-- TODO(sushi) actually use the linker directly
enosi.c.linker = "clang++"

--- C compiler flags that apply to all internal projects
--- TODO(sushi) remove and replace with Driver options
enosi.c.cflags = Twine.new
  "-std=c++20"
  -- "-Wall" someday
  "-Wno-switch"
  -- "-fcolor-diagnostics"
  "-fno-caret-diagnostics"
  "-Wno-#warnings"
  "-Wno-return-type-c-linkage"
  "-fmessage-length=80"
  "-fdiagnostics-absolute-paths"

if enosi.mode == "debug" then
  enosi.c.cflags "-O0" "-ggdb3"
else
  enosi.c.cflags "-O2"
end

--- C linker flags that apply to all internal projects
enosi.c.lflags = Twine.new
  "-fuse-ld=mold"
  "-fmessage-length=80"

local imported_projects = {}

-- The project we are currently importing
---@type Project?
local currently_importing_project = nil

--- Get the project currently being imported.
---@return Project
enosi.thisProject = function()
  return assert(currently_importing_project)
end

--- Try to get an imported project.
---@return Project?
enosi.getProject = function(name)
  return imported_projects[name]
end

enosi.getStaticLibName = function(lib)
  if os == "Linux" then
    return "lib"..lib..".a"
  else
    error("unhandled OS")
  end
end

enosi.getSharedLibName = function(lib)
  if os == "Linux" then
    return "lib"..lib..".so"
  else
    error("unhandled OS")
  end
end

enosi.getUser = function()
  return usercfg
end

local argsParse = function(cmds)
  local argidx = 1
  local args = lake.cliargs

  local iter = {}
  iter.done    = function()  return not args[argidx] end
  iter.current = function()  return args[argidx] end
  iter.at      = function(x) return args[argidx] == x end
  iter.peek    = function()  return args[argidx+1] end
  iter.consume = function()  argidx = argidx + 1 return iter.current() end

  while not iter.done() do
    local cmd = cmds[iter.current()]
    if cmd and cmd(iter) == false then
      return false
    end
    iter.consume()
  end
end

enosi.run = function()
  local Project = require "project"

  -- Import projects based on user config.
  -- Currently user config is requried to specify what projects to build but 
  -- eventually we should have a default list to fallback on.
  assert(usercfg.projects, "user.lua does not specify any projects to build!")

  local tryClean = function(projname)
    ---@type Project
    local proj = imported_projects[projname]
    if not proj or not proj.cleaner then return false end

    proj.log:notice("running cleaner...\n")

    lake.chdir(proj.cleaner[1])
    proj.cleaner[2]()
    lake.chdir(cwd)

    return true
  end

  local allow_post_arg_processing = true

  -- Pre-project-import arg processing
  local arg_result = argsParse
  {
    ["release"] = function(iter)
      enosi.mode = "release"
      -- After projects are done being imported, rules for placing select
      -- executables in the bin/ folder are made.
      allow_post_arg_processing = false
    end
  }
  if arg_result == false then return false end

  List(usercfg.projects):each(function(projname)
    assert(not imported_projects[projname],
      "project '"..projname.."' was already imported!")

    local path = cwd.."/"..projname.."/project.lua"

    assert(lake.pathExists(path),
      "user.lua specified project '"..projname.."', but there is no file "..
      path)

    currently_importing_project =
      Project.new(projname, path)

    imported_projects[projname] = currently_importing_project

    lake.chdir(projname)
    dofile(path)
    lake.chdir(cwd)
  end)

  if enosi.mode == "release" then
    local makeRules = function(...)
      List{...}:each(function(projname)
        local proj = enosi.getProject(projname)
        if not proj then
          error(
            "project "..projname.." specified for release publish, but "..
            "no project with this name has been registered.")
        end

        proj:getExecutables():each(function(exe)
          local dest = cwd.."/bin/"..exe:match(".*/(.*)")
          lake.target(dest)
            :dependsOn(exe)
            :recipe(function()
              lake.copy(dest, exe)
              local reset = "\027[0m"
              local blue  = "\027[0;34m"
              io.write(blue, dest, reset, "\n")
            end)
        end)
      end)
    end

    makeRules(
      -- can't really do lake here because lake will be running from the 
      -- bin folder.. so.. need to replace this process with one that'll
      -- do the copy which is quite complex and i dont feel like doing 
      -- rn
      -- "lake",
      "elua",
      "lpp")
  end

  -- Post-project-import arg processing
  -- This is dumb arg processing, clean up later
  if allow_post_arg_processing then
    local arg_result = argsParse
    {
      ["clean"] = function(iter)
        local proj = iter.peek()
        if proj then
          iter.consume()
          -- clean specific project
          if not tryClean(proj) then
            error("'clean "..proj.."' specified but there's no cleaner "..
            "registered for '"..proj.."'")
          end
        else
          -- clean internal projects
          List { "lpp", "iro", "lake", "lppclang", "ecs" }:each(tryClean)
        end
        return false
      end,

      ["clean-all"] = function()
        -- clean internal and external projects except llvm
        List 
          { "lpp", "iro", "lake", "lppclang", "ecs", "luajit", "notcurses" }
          :each(tryClean)
        return false
      end
    }
    if arg_result == false then return false end
  end
end

return enosi
