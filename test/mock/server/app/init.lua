local M = {}
local config = require 'config'
require 'discovery'


function M.ping()
	return { status = 'ok', instance_name = config.get('etcd.instance_name') }
end

return M