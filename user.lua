return
{
  max_jobs = 6,

  projects =
  {
    "llvm",
    -- "notcurses",
    "luajit",
    "iro",
    "elua",
    "hreload",
    "lppclang",
    "lake",
    "lpp",
    "ecs"
  },

  -- default config for all projects
  default =
  {
    mode = "debug",
    compiler = "clang++",
    linker = "mold",
    disabled_warnings =
    {
      "switch",
      "return-type-c-linkage",
    },
    compiler_flags =
    {
      ["clang++"] =
      {
        "-fmessage-length=80",
        -- "-fcolor-diagnostics",
        -- "-fno-caret-diagnostics",
      }
    },
    linker_flags =
    {
      ["mold"] =
      {
        "-fmessage-length=80",
      }
    },
  },

  llvm =
  {
    mode = "release",
  }
}
