local List = require "list"
local Project = require "project"
local cwd = lake.cwd()

---@class enosi
local enosi = {}

package.path = package.path..";"..cwd.."/?.lua"

-- Try to load the user config and set various settings based on it.
local usercfg = {pcall(require, "user")}

-- Import projects based on user config.
-- Currently user config is requried to specify what projects to build but
-- eventually we should have a default list to fallback on.
assert(usercfg.projects, "user.lua does not specify any projects to build!")

lake.setMaxJobs(usercfg.max_jobs or 1)
lake.mkdir "bin"

local imported_projects = {}

-- The project we are currently importing
---@type Project?
local currently_importing_project = nil

--- Get the project currently being imported.
---@return Project
enosi.thisProject = function()
  return assert(currently_importing_project)
end

--- Get the project currently being imported.
--- The config key to look for in the current project.
---@param key string
---@return any?
enosi.getConfigValue = function(key)
  if currently_importing_project then
    local cfg = usercfg[currently_importing_project] or usercfg["default"]
    if cfg then
      return cfg[key]
    end
  end

  return nil
end

--- Try to get an imported project.
---@return Project?
enosi.getProject = function(name)
  return imported_projects[name]
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

local tryClean = function(projname)
  local proj = imported_projects[projname] ---@type Project
  if not proj or not proj.cleaner then return false end

  proj.log:notice("running cleaner...\n")

  lake.chdir(proj.cleaner[1])
  proj.cleaner[2]()
  lake.chdir(cwd)

  return true
end


-- Pre-project-import arg processing
local allow_post_arg_processing = true
local arg_result = argsParse
{
  ["release"] = function(iter)
    usercfg.default.mode = "release"
    -- After projects are done being imported, rules for placing select
    -- executables in the bin/ folder are made.
    allow_post_arg_processing = false
  end,
  ["patch"] = function(iter)
    local n = iter.consume()
    n = tonumber(n)
    if not n then
      error("expected number after 'patch' command")
    end
    enosi.patch = n
  end
}
if arg_result == false then return false end


-- Gather which projects to import
List(usercfg.projects):each(function(projname)
  assert(not imported_projects[projname],
    "project '"..projname.."' was already imported!")

  local path = cwd.."/"..projname.."/project.lua"

  assert(lake.pathExists(path),
    "user.lua specified project '"..projname.."', but there is no file "..
    path)

  currently_importing_project = Project.new(projname, path)
  imported_projects[projname] = currently_importing_project

  lake.chdir(projname)
  dofile(path)
  lake.chdir(cwd)
end)


-- Publish release builds of projects to bin/
if usercfg.default.mode == "release" then
  local makeRules = function(...)
    List{...}:each(function(projname)
      local proj = imported_projects[projname]
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
        List
        {
          "lpp",
          "iro",
          "lake",
          "lppclang",
          "ecs",
          "hreload"
        }:each(tryClean)
      end
      return false
    end,

    -- clean all projects except llvm
    ["clean-all"] = function()
      List 
      {
        "lpp",
        "iro",
        "lake",
        "lppclang",
        "ecs",
        "hreload",
        "luajit",
        "notcurses"
      }:each(tryClean)
      return false
    end
  }
  if arg_result == false then return false end
end

return enosi