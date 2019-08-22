local util = require "util"

local random = math.random
local pass = util.exit_pass

local function rewrite(args)
end

local function access(args)
	local ratio = args["ratio"] or 1
	if ratio < 1 and ratio < random() then
		ngx.ctx.plugins.limit_ratio = {["limit"] = true}

		return pass()
	end
end

local function content(args)
end

local _M = {
	version = 0.1,
	rewrite = rewrite,
	access = access,
	content = content,
}

return _M
