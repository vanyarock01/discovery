local t = require 'luatest'
local fio = require 'fio'
local log = require 'log'

local helper = {
	server = {},
	client = {},
}

local root = fio.dirname(fio.abspath(debug.getinfo(1, "S").source:sub(2)))
helper.server_datadir = fio.pathjoin(root, 'mock', 'server', 'tmp')
helper.server_root    = fio.pathjoin(root, 'mock', 'server')
helper.server_script  = fio.pathjoin(helper.server_root, 'init.lua')

helper.client_datadir = fio.pathjoin(root, 'mock', 'client', 'tmp')
helper.client_root    = fio.pathjoin(root, 'mock', 'client')
helper.client_script  = fio.pathjoin(helper.client_root, 'init.lua')

helper.server_names = {
	server_001 = { listen_port = 3301 },
	server_002 = { listen_port = 3302 },
	server_003 = { listen_port = 3303 },
}

helper.client_names = {
	client_001 = { listen_port = 4001 },
}

function helper.clear_dir()
	log.info("removing: %s", helper.server_datadir)
	fio.rmtree(helper.server_datadir)
	log.info("removing: %s", helper.client_datadir)
	fio.rmtree(helper.client_datadir)
end

t.before_suite(function()
	helper.clear_dir()
	for name, node_cfg in pairs(helper.server_names) do
		helper.server[name] = t.Server:new({
			command = helper.server_script,
			workdir = helper.server_datadir,
			chdir = helper.server_root,
			env = {
				TT_INSTANCE_NAME = name,
				TT_LUATEST = 'true',
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
	log.info("Server is available")

	for name, node_cfg in pairs(helper.client_names) do
		helper.client[name] = t.Server:new({
			command = helper.client_script,
			workdir = helper.client_datadir,
			chdir = helper.client_root,
			env = {
				TT_INSTANCE_NAME = name,
				TT_LUATEST = 'true',
			},
			net_box_port = node_cfg.listen_port,
			net_box_credentials = {
				user = 'guest',
				password = ''
			}
		})
	end

	helper.client_start()
    helper.client_wait_available()
	log.info("client is available")
end)

t.after_suite(function()
    helper.server_stop()
    helper.client_stop()
	require'fiber'.sleep(0.5)
	helper.clear_dir()
end)

function helper.server_start()
	log.info("Starting server")
    for node, srv in pairs(helper.server) do
		log.info("Starting: %s", node)
        srv:start()
    end
	log.info("Server started")
end

function helper.client_start()
	log.info("Starting client")
    for node, srv in pairs(helper.client) do
		log.info("Starting: %s", node)
        srv:start()
    end
	log.info("client started")
end

function helper.server_stop()
	log.info("Stoping server")
    for _, srv in pairs(helper.server) do
        srv:stop()
    end
end

function helper.client_stop()
	log.info("Stoping client")
    for _, srv in pairs(helper.client) do
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

function helper.client_wait_available()
    for name, srv in pairs(helper.client) do
        t.helpers.retrying({ timeout = 10 }, function() srv:connect_net_box() end)
        t.helpers.retrying({ timeout = 10 }, function()
			assert(srv:call('config.get', {"etcd.instance_name"}) == name)
		end)
    end
end

return helper