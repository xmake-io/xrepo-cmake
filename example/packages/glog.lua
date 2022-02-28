includes("common.lua")
add_requires("glog", {system = false, configs = {gflags = true, shared = true}})
add_requireconfs("glog.gflags", gflags_configs())
