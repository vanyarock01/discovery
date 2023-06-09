local t = require 'luatest'
local g = t.group 'general'

local fiber = require 'fiber'

local helper = require 'test.helper'

g.test_ping = function()
	for name, srv in pairs(helper.server) do
		local r, err = srv:call('app.ping')
		t.assert_equals(err, nil)
		t.assert_equals(r.status, 'ok')
		t.assert_equals(r.instance_name, name)
	end
	for name, cli in pairs(helper.client) do
		local r, err = cli:call('app.ping')
		t.assert_equals(err, nil)
		t.assert_equals(r.status, 'ok')
		t.assert_equals(r.instance_name, name)

		r, err = cli:call('app.call', {'app.ping', {}, { timeout = 1 } })
		t.assert_equals(err, nil)
		t.assert_equals(r.status, 'ok')

		r, err = cli:call('app.call', {'app.ping', {}, { deadline = fiber.time()+1 } })
		t.assert_equals(err, nil)
		t.assert_equals(r.status, 'ok')

		r, err = cli:call('app.call', {'app.ping', {}, { deadline = fiber.time()+1, timeout = 1 } })
		t.assert_equals(err, nil)
		t.assert_equals(r.status, 'ok')
	end
end


g.test_sleep = function()
	fiber.sleep(3)
	local instances = {}
	for i = 1, 1000 do
		for name, cli in pairs(helper.client) do
			local req = ("%s:%s"):format(name, i)
			local r, err = cli:call('app.call', {'app.timeout_even', {req}, { timeout = 0.1, deadline = fiber.time()+1 } })
			t.assert_equals(err, nil)
			t.assert_equals(r.status, 'ok')
			t.assert_type(r.instance_name, 'string', 'instance_name must be present in response')
			instances[r.instance_name] = true
		end
	end

	for name in pairs(helper.server) do
		t.assert(instances[name], ("instance %s was not visited"):format(name))
	end
end
