/*
 *  enosi-lua, a luajit executable that links all of iro's lua obj files
 *  to keep running lua scripts in projects easy.
 *
 */ 

#include "iro/common.h"
#include "iro/unicode.h"
#include "iro/luastate.h"
#include "iro/logger.h"
#include "iro/fs/fs.h"

using namespace iro;

int main(int argc, const char** argv)
{
  iro::log.init();
  defer { iro::log.deinit(); };

  Logger logger;
  logger.init("elua"_str, Logger::Verbosity::Trace);

  {
    using enum Log::Dest::Flag;
    Log::Dest::Flags flags;

    if (fs::stderr.isatty())
    {
      flags = 
          AllowColor
        | ShowCategoryName
        | ShowVerbosity
        | TrackLongestName
        | PadVerbosity
        | PrefixNewlines;
    }
    else
    {
      flags = 
          ShowCategoryName
        | ShowVerbosity
        | PrefixNewlines;
    }

    iro::log.newDestination("stderr"_str, &fs::stderr, flags);
  }

  LuaState lua = {};
  if (!lua.init())
    return 1;
  defer { lua.deinit(); };

  if (argc != 2)
  {
    ERROR("elua only takes one argument: the path to the script to execute\n");
    return 1;
  }

  if (!lua.loadfile(argv[1]))
  {
    ERROR("failed to load script at path '", argv[1], "'\n");
    return 1;
  }

  if (!lua.pcall())
  {
    ERROR("script failed: ", lua.tostring(), "\n");
    return 1;
  }

  return 0;
}
