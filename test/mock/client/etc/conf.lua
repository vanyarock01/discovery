local instance_name = os.getenv "TT_INSTANCE_NAME"
local fio = require 'fio'
local dir = fio.abspath('./tmp/'..instance_name)

etcd = { --luacheck: ignore
	endpoints = {'http://localhost:2379'},
	prefix = "/",
	timeout = 1,
	instance_name = instance_name;
	uuid = 'auto',
	boolean_auto = true,
	discover_endpoints = false,
	print_config = true,

	fixed = {
		common = {
			box = {
				vinyl_memory = 0,
				vinyl_cache = 0,
				memtx_memory = 32*2^30,
			},
			users = {
				guest = {
					roles = {'super'},
				}
			},
		},
		clusters = {
			simple_cluster_001 = {
				master = 'instance_001',
			},
		},
		instances = {
			instance_001 = {
				cluster = 'simple_cluster_001',
				box = { listen = '127.0.0.1:3301' },
			},
			instance_002 = {
				cluster = 'simple_cluster_001',
				box = { listen = '127.0.0.1:3302' },
			},
			instance_003 = {
				cluster = 'simple_cluster',
				box = { listen = '127.0.0.1:3303' },
			},
		},
	},
}

box = { --luacheck: ignore
	work_dir  = fio.abspath('.'),
	memtx_dir = dir,
	wal_dir   = dir,
	vinyl_dir = dir,
}