local config = require 'config'

local M = {
	server = require 'discovery' {
		upstream = {
			endpoints = {'127.0.0.1:3301', '127.0.0.1:3302', '127.0.0.1:3303'},
			net_box_timeout = 1,
			reconnect_timeout = config.get('app.discovery.reconnect', 0.3),
			--[[
				etcd = {
					refresh_timeout = 1,
					prefix = "/server",
					timeout = 1,
					boolean_auto = true,
					integer_auto = true,
					master_selection_policy = 'etcd.cluster.master',
				},
			]]
		},
		discovery = {
			method = config.get('app.discovery.method', 'app.discovery'),
			net_box_timeout = config.get('app.discovery.timeout', 1),
			refresh_timeout = config.get('app.discovery.refresh_timeout', 0.1),
		},
	},
}

function M.ping()
	return { status = 'ok', instance_name = config.get('etcd.instance_name') }
end

function M.call(method, args, opts)
	return M.server:call(method, args, opts)
end

function M.discovery()
	return M.server:discovery()
end

return M