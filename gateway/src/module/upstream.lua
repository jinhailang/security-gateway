local healthcheck = require "resty.healthcheck"
local lrucache = require "lrucache"
local roundrobin = require "resty.roundrobin"
local chash = require "resty.chash"
local cjson = require "cjson"
local util = require "util"

local new_lru = lrucache.new
local check_new = healthcheck.new
local encode = cjson.encode
local parse_addr = util.parse_addr

local ngx_log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local tab_new = table.new
local tab_nkeys = table.nkeys

local _M = {version = 0.1}


local function checker_release(checker)
	checker:stop()
end

local lrucache_server = new_lru({
	 ttl = 300, count = 256
})
local lrucache_checker = new_lru({
	ttl = 300, count = 256, release = checker_release
})

local function create_checker(upstream)
	local checker = check_new({
		name = "upstream",
		shm_name = "healthcheck",
		checks = upstream.checks,
	})

	for addr, _ in pairs(upstream.nodes) do
		local ip, port = parse_addr(addr)
		local ok, err = checker:add_target(ip, port, checker.checks.host)
		if not ok then
			ngx_log(ERR, "add_target error: ", err, ". addr: ", addr)
		end
	end

	ngx_log(INFO, "create checker.")
	return checker
end

local function get_checker(upstream, version)
	return lrucache_checker(upstream, version, create_checker, upstream)
end

local function get_nodes(upstream, checker)
	if not checker then
		return upstream.nodes
	end

	local host = checker.checks.host
	local health_nodes = tab_new(0, #upstream.nodes)

	for addr, weight in pairs(upstream.nodes) do
		local ip, port = parse_addr(addr)
		local ok = checker:get_target_status(ip, port, host)
		if ok then
			health_nodes[addr] = weight
		end
	end

	if tab_nkeys(health_nodes) == 0 then
		ngx_log(ERR, "all upstream nodes is unhealth, default use update.nodes.")
		return upstream.nodes
	end

	return health_nodes
end

local function create_upstream(upstream, checker)
	local typ = upstream.type or "roundrobin"
	local health_nodes = get_nodes(upstream, checker)
	ngx_log(INFO, "health upstream nodes: ", encode(health_nodes))

	if typ == "roundrobin" then
		local rb = roundrobin:new(health_nodes)
		return {upstream = upstream, get = function() return rb:find() end}
	elseif typ == "chash" then
		-- we can do the following steps to keep consistency with nginx chash
		local str_null = string.char(0)
		local servers, nodes = {}, {}

		for serv, weight in pairs(health_nodes) do
			local id = string.gsub(serv, ":", str_null)

			servers[id] = serv
			nodes[id] = weight
		end

		local ch = chash:new(nodes)
		local key = upstream.key or "uri"

		return {
			upstream = upstream,
			get = function(var)
				local id = ch:find(var[key])
				return servers[id]
			end
		}
	else
		return nil, "invalid balancer type: " .. typ
	end
end

function _M.get_host(service, version)
	local id = service.service_id
	local upstream = service.upstream

	local key = upstream.type .. "#service_" .. id

	local checker = get_checker(upstream, version)
	if checker then
		version = version .. "#" .. checker.status_ver
	end

	local us = lrucache_server(key, version, create_upstream, upstream, checker)
	if not us then
		return nil, "failed to get upstream server"
	end

	local server, err = us.get(ngx.var)
	if not server then
		return nil, "failed to find valid upstream server" .. err
	end

	return server, err
end


return _M
