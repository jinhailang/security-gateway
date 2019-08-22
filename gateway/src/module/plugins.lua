local limit_ratio = require "plugins.limit_ratio"

local _M = {version = 0.1}

_M.run = {
	["limit-ratio"] = limit_ratio,
}

return _M
