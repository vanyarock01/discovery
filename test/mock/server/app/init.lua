local M = {}
local config = require 'config'

function M.ping()
	return {
		status = 'ok',
		instance_name = config.get('etcd.instance_name'),
		is_master = box.info.ro == false,
	}
end

function M.ping_master()
	return M.ping()
end

function M.ping_replica()
	return M.ping()
end

function M.ping_better_replica()
	return M.ping()
end

function M.discovery()
	if box.info.ro then
		return {
			is_master = false,
			methods = {
				["app.ping"] = { weight = 100, retriable = true },
				["app.ping_master"] = { weight = 0 },
				["app.ping_replica"] = { weight = 100 },
				["app.ping_better_replica"] = { weight = 100 },
			},
		}
	else
		return {
			is_master = false,
			methods = {
				["app.ping"] = { weight = 100, retriable = true },
				["app.ping_master"] = { weight = 100 },
				["app.ping_replica"] = { weight = 0 },
				["app.ping_better_replica"] = { weight = 10 },
			},
		}
	end
end

return M