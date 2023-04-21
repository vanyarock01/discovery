local M = {}
local fiber = require 'fiber'
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

M.etcd_f = require 'background' {
	name = 'etcd_f',
	wait = false,
	eternal = false,
	run_interval = config.get('etcd.fencing_timeout', 10),
	func = function(job)
		local allcfg = config.etcd:get_all()
		local my_instance_name = config.get('sys.instance_name') or config.get('etcd.instance_name')
		local my_instance = allcfg.instances[my_instance_name]
		local my_shard = allcfg.clusters[my_instance.cluster]
		local my_master = allcfg.instances[my_shard.master]

		local repl = box.info.replication
		local master_id
		for _, info in pairs(repl) do
			if info.uuid == my_master.box.instance_uuid then
				master_id = info.id
				break
			end
		end

		M.my_master = {
			master_name = my_shard.master,
			master_instance_uuid = my_master.box.instance_uuid,
			master_id = master_id,
			valid_till = fiber.time() + job.run_interval*2,
		}
	end,
}

function M.discovery()
	if box.info.status ~= "running" then
		return {
			is_master = not box.info.ro,
			methods = {},
		}
	end
	if box.info.ro then
		local m = 1
		if M.my_master and M.my_master.master_id and box.info.replication[M.my_master.master_id] then
			local repl_info = box.info.replication[M.my_master.master_id]

			local upstream_lag, downstream_lag
			if repl_info.upstream then
				upstream_lag = math.abs((repl_info.upstream.status == "follow" and repl_info.upstream.lag)
					or repl_info.upstream.idle)
			end
			if repl_info.downstream then
				downstream_lag = math.abs((repl_info.downstream.status == "follow" and repl_info.downstream.lag)
					or repl_info.downstream.idle)
			end

			local lag = math.max(upstream_lag or 0, downstream_lag or 0)
			m = 1 / (1+lag^2)
		end
		return {
			is_master = false,
			methods = {
				["app.ping"] = { weight = math.floor(m*100), retriable = true },
				["app.ping_master"] = { weight = math.floor(m*0) },
				["app.ping_replica"] = { weight = math.floor(m*100) },
				["app.ping_better_replica"] = { weight = math.floor(m*100) },
				["app.ping_"..config.get('etcd.instance_name')] = { weight = 100, retriable = true, alias='app.ping' },
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
				["app.ping_"..config.get('etcd.instance_name')] = { weight = 100, retriable = true, alias='app.ping' },
			},
		}
	end
end

return M