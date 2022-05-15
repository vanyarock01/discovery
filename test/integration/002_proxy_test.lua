local t = require 'luatest'
local g = t.group 'proxy'

local helper = require 'test.helper'

g.test_proxy_call = function()
	for _, cli in pairs(helper.client) do
		for _ = 1, 1000 do
			local r, err = cli:call('app.call', {"app.ping_master", {}, { timeout = 10 }})
			t.assert_equals(err, nil)
			t.assert_equals(r.status, 'ok')
			t.assert_equals(r.instance_name, 'instance_001')
			t.assert_equals(r.is_master, true)
		end
	end

	for _, cli in pairs(helper.client) do
		for _ = 1, 1000 do
			local r, err = cli:call('app.call', {"app.ping_replica", {}, { timeout = 10 }})
			t.assert_equals(err, nil)
			t.assert_equals(r.status, 'ok')
			t.assert_not_equals(r.instance_name, 'instance_001')
			t.assert_equals(r.is_master, false)
		end
	end

	for _, cli in pairs(helper.client) do
		local res = {}
		for _ = 1, 10000 do
			local r, err = cli:call('app.call', {"app.ping_better_replica", {}, { timeout = 10 }})
			t.assert_equals(err, nil)
			t.assert_equals(r.status, 'ok')
			res[r.instance_name] = (res[r.instance_name] or 0) + 1
		end
		require'log'.info(res)
	end

	for _, cli in pairs(helper.client) do
		local res = {}
		for _ = 1, 10000 do
			local r, err = cli:call('app.call', {"app.ping", {}, { timeout = 10 }})
			t.assert_equals(err, nil)
			t.assert_equals(r.status, 'ok')
			res[r.instance_name] = (res[r.instance_name] or 0) + 1
		end
		require'log'.info(res)
	end
end