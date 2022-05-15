package = "discovery"
version = "scm-1"
source = {
   url = "https://github.com/moonlibs/discovery.git",
   branch = "master"
}
description = {
   homepage = "https://github.com/moonlibs/discovery",
   license = "BSD",
}
dependencies = {
   "lua ~> 5.1",
   "background scm-1",
}
build = {
   type = "builtin",
   modules = {}
}
