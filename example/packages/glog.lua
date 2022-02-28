--includes("common.lua")
add_requires("glog", {system = false, configs = {gflags = true, shared = true}})
add_requireconfs("glog.gflags", {system = false, configs = {mt = true, shared = true, debug = true}})
--add_requireconfs("glog.gflags", gflags_configs())
