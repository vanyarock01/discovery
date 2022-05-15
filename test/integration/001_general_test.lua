local t = require 'luatest'
local g = t.group 'general'

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
	end
end