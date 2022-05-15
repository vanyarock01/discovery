#!/usr/bin/env tarantool
require 'strict'.on()
local fio = require 'fio'
local root = fio.dirname(fio.abspath(debug.getinfo(1, "S").source:sub(2)))
local libs = fio.pathjoin(root, '..', '..', '..')
package.path = table.concat({package.path, libs..'/?.lua', libs..'/?/init.lua'}, ';')

require 'config' {
	mkdir = true,
	file = 'etc/conf.lua',
	master_selection_policy = 'etcd.instance.read_only',
	on_after_cfg = function()
		if box.info.ro then
			return
		end
		box.schema.user.grant('guest', 'super', nil, nil, { if_not_exists = true })
	end,
}

rawset(_G, 'app', require 'app')
