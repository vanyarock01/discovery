#!/usr/bin/env tarantool
require 'strict'.on()
local fio = require 'fio'
local root = fio.dirname(fio.abspath(debug.getinfo(1, "S").source:sub(2)))
local libs = fio.pathjoin(root, '..', '..', '..')
package.path = table.concat({package.path, libs..'/?.lua', libs..'/?/init.lua'}, ';')

require 'config' {
	mkdir = true,
	file = 'etc/conf.lua',
	master_selection_policy = 'etcd.cluster.master',
	on_after_cfg = function(cfg)
		if box.info.ro then return end

		for user, uinfo in pairs(cfg.get('users')) do
			box.schema.user.create(user, { if_not_exists = true })
			box.schema.user.passwd(user, uinfo.passwd or '')

			for _, role in ipairs(uinfo.roles or {}) do
				box.schema.user.grant(user, role, nil, nil, { if_not_exists = true })
			end
		end
	end,
}

rawset(_G, 'app', require 'app')
