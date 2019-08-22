local upstream = require "upstream"
local util = require "util"
local etcd = require "etcd"
local http = require "resty.http"
local stat = require "stat"

local parse_addr = util.parse_addr
local get_host = upstream.get_host
local get_service = etcd.get_service
local pass = util.exit_pass
local block = util.exit_block
local ngx_log = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG
local INFO = ngx.INFO
local timer_at = ngx.timer.at
local tab_nkeys = table.nkeys
local tab_new = table.new
local ngx_sleep = ngx.sleep
local random = math.random

local item = ngx.ctx.item

if item then
	local item_services = item.services

	if not item_services or #item_services == 0 then
		ngx_log(ERR, "match route services not nil.")
		return pass()
	end

	local rd = random()
	local host_service = {}
	local services = get_service() or {}
	local services_version = services["_version"]

	for _, service_id in ipairs(item_services) do
		if service_id == 0 then
			return pass()
		end

		local service = services[tostring(service_id)]
		if not service or not service.upstream then
			ngx_log(ERR, "service not found, or service upstream is nil. service_id: " .. service_id)
		else
			-- service limit
			local limit_ratio = service.limit_ratio or 1
			if limit_ratio < 1 and limit_ratio < rd then
				goto continue
			end

			local host, err = get_host(service, services_version)
			if err then
				ngx_log(ERR, "get upstream host error: " .. err)
			else
				host_service[host] = service
			end
		end

		::continue::
	end

	ngx.req.read_body()

	local req_method = ngx.req.get_method()
	local req_body = ngx.req.get_body_data()
	local req_headers = ngx.req.get_headers()
	local req_uri = ngx.var.uri
	if ngx.var.is_args == "?" then
		req_uri = req_uri .. "?" .. ngx.var.query_string
	end

	req_headers["X-Real-IP"] = ngx.var.remote_addr

	local send = function(premature, host, serv, resps)
		if premature then
			resps[host] = false

			return
		end

		local httpc = http.new()

		local timeout = serv.upstream.timeout or 300

		httpc:set_timeout(timeout)
		httpc:connect(parse_addr(host))

		stat.stat_service(serv.service_id)

		local res, err = httpc:request({
			version = 1.1,
			path = req_uri,
			method = req_method,
			body = req_body,
			headers = req_headers,
			keepalive_timeout = 30,
		})

		local bk = false
		if err then
			ngx.log(ngx.ERR, "failed to request: ", err, ". path: ", req_uri, "host: ", host)
		else
			httpc:set_keepalive(30, 16)

			local status = res.status or 0

			ngx_log(DEBUG, "send host: ", host, ", status: ", status)

			if status == 200 then
				local reader = res.body_reader
				local chunk, _ = reader(1)

				if not chunk then
					bk = true
				end
			elseif status == 403 or status == 400 then
				bk = true
			end
		end

		resps[host] = bk
	end

	-- asynchronous send request
	local sm = 0
	local cnt = tab_nkeys(host_service)
	local resps = tab_new(0, cnt)

	for host, serv in pairs(host_service) do
		local ok, err = timer_at(0, send, host, serv, resps)
		if not ok then
			ngx_log(ERR, "ngx.time.at errror: ", err, ". host: ", host)
		else
			sm = sm + 1
		end
	end

	-- wait for request result
	local count = 10
	while(count >= 0) do
		count = count - 1
		ngx_sleep(0.05)

		if tab_nkeys(resps) == sm then
			for host, bk in pairs(resps) do
				if bk then
					ngx.ctx.block = {host=host, service=host_service[host]}

					return block()
				end
			end

			return pass()
		end
	end

	ngx_log(INFO, "wait for request result timeout. resps: ", encode(resps))
end

-- default pass
return pass()
