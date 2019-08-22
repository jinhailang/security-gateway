local route = require "route"
local util = require "util"
local config = require "config"
local plugins = require "plugins"
local stat = require "stat"

local random = math.random
local pass = util.exit_pass
local cfg = config.get_cfg()
local match = route.match
local req_host = ngx.var.host
local req_method = ngx.req.get_method()
local req_uri = ngx.var.uri

ngx.ctx.plugins = {}

-- limit
local limit_ratio = cfg["limit_ratio"] or 1
if limit_ratio < 1 and limit_ratio < random() then
	ngx.ctx.ignore = true
	return pass
end

stat.stat_all()

-- generate request id
local req_id = util.gen_id() or ""

ngx.ctx.request_id = req_id
ngx.header["x-request-id"] = req_id

local rt, it = match(req_host, req_method, req_uri)
if rt then
	ngx.ctx.route = rt
	ngx.ctx.item = it

	stat.stat_route(rt.id)

	-- run plugins
	local route_plugins = it.plugins or {}

	for name, args in pairs(route_plugins) do
		plugins.run[name].access(args)
	end
end
