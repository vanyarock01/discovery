local t = require 'luatest'
local fio = require 'fio'
local log = require 'log'

local helper = {
	server = {},
}

local root = fio.dirname(fio.abspath(debug.getinfo(1, "S").source:sub(2)))
helper.datadir = fio.pathjoin(root, 'mock', 'server', 'tmp')
helper.root    = fio.pathjoin(root, 'mock', 'server')
helper.script  = fio.pathjoin(helper.root, 'init.lua')

helper.server_names = {
	instance_001 = { listen_port = 3301 },
	instance_002 = { listen_port = 3302 },
	instance_003 = { listen_port = 3303 },
}

function helper.clear_dir()
	log.info("removing: %s", helper.datadir)
	fio.rmtree(helper.datadir)
end

t.before_suite(function()
	helper.clear_dir()
	for name, node_cfg in pairs(helper.server_names) do
		helper.server[name] = t.Server:new({
			command = helper.script,
			workdir = helper.datadir,
			chdir = helper.root,
			env = {
				TT_INSTANCE_NAME = name,
				TT_NOCONSOLE = 'true',
				TT_CONFIG = 'etc/conf.lua',
				TT_LISTEN = node_cfg.listen_port,
			},
			net_box_port = node_cfg.listen_port,
			net_box_credentials = {
				user = 'guest',
				password = ''
			}
		})
	end

    helper.server_start()
    helper.server_wait_available()
	log.info("Cluster is available")
end)

t.after_suite(function()
    helper.server_stop()
	require'fiber'.sleep(0.5)
	helper.clear_dir()
end)

function helper.server_start()
	log.info("Starting cluster")
    for node, srv in pairs(helper.server) do
		log.info("Starting: %s", node)
        srv:start()
    end
	log.info("Cluster started")
end

function helper.server_stop()
	log.info("Stoping cluster")
    for _, srv in pairs(helper.server) do
        srv:stop()
    end
end

function helper.server_wait_available()
    for name, srv in pairs(helper.server) do
        t.helpers.retrying({ timeout = 10 }, function() srv:connect_net_box() end)
        t.helpers.retrying({ timeout = 10 }, function()
			assert(srv:call('config.get', {"etcd.instance_name"}) == name)
		end)
    end
end

return helper