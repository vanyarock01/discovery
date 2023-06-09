local config = require 'config'
local json = require 'json'
local log = require 'log'

local is_luatest = os.getenv "TT_LUATEST"
local endpoints, etcd
if is_luatest then
	endpoints = {"127.0.0.1:3301", "127.0.0.1:3302", "127.0.0.1:3303"}
else
	etcd = { refresh_timeout = 1, prefix = '/instances/' }
end

local M = {
	server = require 'discovery' {
		upstream = {
			-- Endpoints and ETCD mutually exclusive.
			endpoints = endpoints,
			etcd = etcd,

			net_box_timeout = 1,
			reconnect_timeout = config.get('app.discovery.reconnect', 0.3),
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
	log.verbose("proxy call %s %s %s", method, json.encode(args), json.encode(opts))
	return M.server:call(method, args, opts)
end

function M.discovery()
	return M.server:discovery()
end

return M
