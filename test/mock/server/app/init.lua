local M = {}
local config = require 'config'
local fiber = require 'fiber'
local log = require 'log'
local json = require 'json'


function M.ping()
	return {
		status = 'ok',
		instance_name = config.get('etcd.instance_name'),
		is_master = box.info.ro == false,
	}
end

local no = 0
function M.timeout_even(req)
	log.verbose("Called %s on %s", json.encode(req), config.get('etcd.instance_name'))
	no = no + 1
	local length = box.space._cluster:len()

	if no % length == box.info.id then
		fiber.sleep(1)
	end

	return { status = 'ok', instance_name = config.get('etcd.instance_name') }
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
				["app.timeout_even"] = { weight = 100, retriable = true },
			},
		}
	else
		return {
			is_master = true,
			methods = {
				["app.ping"] = { weight = 100, retriable = true },
				["app.ping_master"] = { weight = 100 },
				["app.ping_replica"] = { weight = 0 },
				["app.ping_better_replica"] = { weight = 10 },
				["app.timeout_even"] = { weight = 100, retriable = true },
			},
		}
	end
end

return M
