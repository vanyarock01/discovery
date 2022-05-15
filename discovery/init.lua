local M = {}
local log = require 'log'
local fiber = require 'fiber'
local netbox = require 'net.box'
local background = require 'background'

local Tarantool = {}
Tarantool.__index = {}

function Tarantool.new(_, opts)
	assert(opts.addr, "Tarantool:new: opts.addr is required")
	assert(opts.timeout, "Tarantool:new opts.timeout is required")

	local self = setmetatable(opts, Tarantool)

	local conn = netbox.connect(opts.addr, {
		reconnect_after = opts.reconnect_timeout,
		wait_connected = opts.async or false,
		timeout = self.timeout,
	})

	self.conn = conn
	self.connected = false

	conn:on_connect(function(_)
		fiber.create(function()
			fiber.name('dsc/cnt:'..conn.host..':'..conn.port)

			self.connected = true
			log.info("Connected to %s:%s", conn.host, conn.port)

			if opts.on_connect then
				local ok, err = pcall(opts.on_connect, self)
				if not ok then
					log.error("on_connect hook failed: %s", err)
				end
			end
		end)
	end)
	conn:on_disconnect(function(_)
		fiber.create(function()
			fiber.name('dsc/dsc:'..conn.host..':'..conn.port)

			self.connected = false
			log.info("Connected to %s:%s", conn.host, conn.port)

			if opts.on_disconnect then
				local ok, err = pcall(opts.on_disconnect, self)
				if not ok then
					log.error("on_disconnect hook failed: %s", err)
				end
			end
		end)
	end)

	return self
end
setmetatable(Tarantool, { __call = Tarantool.new })


function M.new(_, args)
	assert(type(args) == 'table', "discovery: args must be a table")
	assert(type(args.discovery) == 'table', "discovery: args.discovery must be a table")
	assert(type(args.upstream) == 'table', "discovery: args.upstream must be a table")

	if not args.upstream.endpoints and not args.upstream.etcd then
		error("discovery: one of args.upstream.endpoints or args.upstream.etcd must be specified")
	end
	if args.upstream.endpoints and args.upstream.etcd then
		error("discovery: you must specify args.upstream.endpoints xor args.upstream.etcd")
	end

	args.upstream.net_box_timeout = args.upstream.net_box_timeout or 1

	if args.upstream.reconnect_timeout == nil then
		args.upstream.reconnect_timeout = 0.3
	end

	args.discovery.refresh_timeout = args.discovery.refresh_timeout or 0.1
	args.discovery.net_box_timeout = args.discovery.net_box_timeout or 1

	local self = setmetatable(args, {__index = M})
	self.nodes = {}
	self.methods = {}
	self.methods_list = {}
	self.conds = {}

	if self.autoconnect ~= false then
		self:connect()
	end

	return self
end

function M:connect()
	for _, addr in pairs(self.upstream.endpoints) do
		self.nodes[addr] = Tarantool {
			addr = addr,
			reconnect_timeout = self.upstream.reconnect_timeout,
			timeout = self.upstream.net_box_timeout,
			on_connect = function(tnt)
				self:on_connect(addr, tnt)
			end,
			on_disconnect = function(tnt)
				self:on_disconnect(addr, tnt)
			end,
		}
	end
end

function M:on_connect(addr, tnt)
	tnt.discovery_f = background {
		name = 'discovery/'..tnt.conn.host..':'..tnt.conn.port,
		setup = function(ctx) ctx.tnt = tnt end,
		run_interval = self.discovery.refresh_timeout,
		restart = 2*math.max(self.discovery.refresh_timeout, self.discovery.net_box_timeout),
		wait = false, -- wait noone
		func = function(ctx)
			local res = ctx.tnt.conn:call(self.discovery.method, {}, { timeout = self.discovery.net_box_timeout })
			self:on_discovery(addr, res)
		end,
	}
end

function M:on_disconnect(addr, tnt)
	log.info("Gracefull shutdown for background discovery for %s", addr)
	tnt.discovery_f:shutdown()
	self:on_undiscovery(addr)
end

function M:on_discovery(addr, res)
	assert(type(res) == 'table', "discovered response must be a table")
	assert(type(res.methods) == 'table', "discoverred response must contain methods")

	assert(self.nodes[addr].connected, "Node must be connected")

	local do_rebuild = false
	for method, info in pairs(res.methods) do
		if not self.methods[method] then
			self.methods[method] = {}
		end
		if not self.methods[method][addr] then
			self.methods[method][addr] = {}
		end
		for _, key in ipairs{"weight", "retriable"} do
			if self.methods[method][addr][key] ~= info[key] then
				do_rebuild = true
			end
		end
		self.methods[method][addr] = info
	end

	if do_rebuild then
		self:rebuild()
	end
end

function M:on_undiscovery(addr)
	self:rebuild()
	log.info("Methods of %s undiscovered", addr)
end

function M:rebuild()
	for method in pairs(self.methods) do
		for addr in pairs(self.methods[method]) do
			if not self.nodes[addr] then
				log.warn("Node %s is not registered in discovery but exists in balancer graph", addr)
				self.methods[method][addr] = nil
			elseif not self.nodes[addr].connected then
				log.warn("Disable %s:%s because disconnected", method, addr)
				self.methods[method][addr] = nil
			end
		end
		local list = {}
		local total_weight = 0
		local addrs = {}

		for node_addr, balance in pairs(self.methods[method]) do
			if balance.weight ~= 0 then
				total_weight = total_weight + balance.weight
				table.insert(list, { addr = node_addr, max_weight = total_weight })
				table.insert(addrs, ("%s:%s"):format(node_addr, total_weight))
			end
		end

		self.methods_list[method] = list

		if #list > 0 then
			log.verbose("Rebuilded %s: %s", method, table.concat(addrs, ","))
			if self.conds[method] then
				self.conds[method]:broadcast()
			end
		end
	end
end

local function tail_call(self, ctx, pcall_ok, ...)
	if pcall_ok then
		log.verbose("[Proxy=ok] to %s in %.5fs (total: %.5fs)",
			ctx.addr, fiber.time()-ctx.executed_at, fiber.time()-ctx.started_at)
		return ...
	end

	log.error("call %s to {%s} failed with: %s", ctx.method, ctx.addr, ...)

	if ctx.retriable then
		return self:call(ctx.method, ctx.args, ctx.opts, ctx)
	end

	error(...)
end

function M:call(method, args, opts, ctx)
	args = args or {}
	opts = opts or {}
	opts.timeout = opts.timeout or self.upstream.net_box_timeout

	ctx = ctx or {
		started_at = fiber.time(),
		attempt = 0,
		method = method,
		args = args,
	}

	local deadline = ctx.deadline or opts.deadline or (fiber.time() + opts.timeout)
	if deadline < fiber.time() then
		return false, "TimedOut of discovery reached"
	end

	ctx.deadline = deadline

	local balance = self.methods_list[method]
	if not balance or #balance == 0 then
		log.verbose("No nodes available for %s. Waiting %.3fs", method, deadline - fiber.time())
		self.conds[method] = self.conds[method] or fiber.cond()
		self.conds[method]:wait(deadline - fiber.time())
		return self:call(method, args, opts, ctx)
	end

	local rnd = math.random(0, balance[#balance].max_weight)
	local node do
		for i = 1, #balance do
			if rnd <= balance[i].max_weight then
				node = balance[i]
				break
			end
		end
	end

	ctx.retriable = node.retriable == true
	ctx.addr = node.addr
	ctx.attempt = ctx.attempt + 1
	opts.timeout = math.min(deadline - fiber.time(), opts.timeout)
	ctx.executed_at = fiber.time()
	log.verbose("Calling on %s (attempt #%d)", node.addr, ctx.attempt)
	local conn = self.nodes[node.addr].conn
	return tail_call(self, ctx, pcall(conn.call, conn, method, args, opts))
end

setmetatable(M, {__call = M.new})
return M