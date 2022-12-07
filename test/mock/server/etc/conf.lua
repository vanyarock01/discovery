local instance_name = os.getenv "TT_INSTANCE_NAME"
local fio = require 'fio'
local dir = fio.abspath('./tmp/'..instance_name)

local is_luatest = os.getenv "TT_LUATEST"
local bind_urls = {
	server_001 = is_luatest and '127.0.0.1:3301' or 'server_001:3301',
	server_002 = is_luatest and '127.0.0.1:3302' or 'server_002:3302',
	server_003 = is_luatest and '127.0.0.1:3303' or 'server_003:3303',
}

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
				log_format = 'plain',
				log_level = 5,
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
				master = 'server_001',
			},
		},
		instances = {
			server_001 = {
				cluster = 'simple_cluster_001',
				box = { listen = bind_urls['server_001'] },
			},
			server_002 = {
				cluster = 'simple_cluster_001',
				box = { listen = bind_urls['server_002'] },
			},
			server_003 = {
				cluster = 'simple_cluster_001',
				box = { listen = bind_urls['server_003'] },
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