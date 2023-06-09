local instance_name = os.getenv "TT_INSTANCE_NAME"
local fio = require 'fio'
local dir = fio.abspath('./tmp/'..instance_name)

local is_luatest = os.getenv "TT_LUATEST"
local bind_urls = {
	server_001 = is_luatest and '127.0.0.1:3301' or 'server_001:3301',
	server_002 = is_luatest and '127.0.0.1:3302' or 'server_002:3302',
	server_003 = is_luatest and '127.0.0.1:3303' or 'server_003:3303',
	client_001 = is_luatest and '127.0.0.1:4001' or 'client_001:4001',
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
				log_level = 5,
				log_format = 'plain',
				vinyl_memory = 0,
				vinyl_cache = 0,
				memtx_memory = 32*2^20,
			},
		},
		clusters = {
			simple_cluster_001 = { master = 'instance_001' },
			client_001 = { master = 'client_001' },
		},
		instances = {
			instance_001 = {
				cluster = 'simple_cluster_001',
				box = { listen = bind_urls['server_001'] },
			},
			instance_002 = {
				cluster = 'simple_cluster_001',
				box = { listen = bind_urls['server_002'] },
			},
			instance_003 = {
				cluster = 'simple_cluster',
				box = { listen = bind_urls['server_003'] },
			},
			client_001 = {
				disabled = true,
				cluster = 'client_001',
				box = {
					listen = bind_urls['client_001'],
					read_only = false,
				},
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
