package = "mmap"
version = "0.1-0"
source = {
  url = "git://github.com/StephenMcGill-TRI/luajit-mmap.git"
}
description = {
  summary = "Open files using memory mapping",
  detailed = [[
      Open files using memory mapping, with a shared memory interface.
    ]],
  homepage = "https://github.com/StephenMcGill-TRI/luajit-mmap",
  maintainer = "Stephen McGill <stephen.mcgill@tri.global>",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",

  modules = {
    ["mmap"] = "mmap.lua",
  }
}
