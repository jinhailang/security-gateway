local logger = require "logger"
local util = require "util"

local get_header = util.get_headers_value
local log_send = logger.send
local escape    = ngx.escape_uri
local ngx_time = ngx.time

local detection = {}
local ctx = ngx.ctx

-- ignore global limit request log
if ctx.ignore then
	return
end

if ctx.item then
	local rt = ctx.route
	local it = ctx.item
	local block = ctx.block

	detection = {
		id = rt.id,
		route_id = it.route_id,
		domain = rt.domain,
		block = false,
		plugins = ctx.plugins or {},
	}

	if block then
		local service = block.service

		detection["block"] = true
		detection["service_id"] = service.service_id
		detection["block_host"] = block.host
	end
end

local msg = {
	detection = detection,
	uri = escape(ngx.var.uri) or "",
	status = ngx.status,
	timestamp = ngx_time(),
	host = ngx.var.host or "",
	method = ngx.req.get_method(),
	request_length = ngx.var.request_length,
	bytes_sent = ngx.var.bytes_sent,
	request_time = ngx.var.request_time,
	remote_addr = ngx.var.remote_addr,
	x_forwarded_for = get_header("x-forwarded-for"),
	user_agent = get_header("user-agent"),
	referer = get_header("referer"),
	x_real_ip = get_header("x-real-ip"),
	request_id = ctx.request_id,
}

log_send(msg, "access")
