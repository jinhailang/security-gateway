local etcd = require "etcd"
local cjson = require "cjson"

local encode = cjson.encode
local ngx_timer_every = ngx.timer.every
local ngx_log = ngx.log
local ERR = ngx.ERR
local INFO = ngx.INFO
local DEBUG = ngx.DEBUG
local str_sub = string.sub
local ngx_match = ngx.re.match
local str_match = string.match
local tab_insert = table.insert
local get_route = etcd.get_route

local _M = {version = 0.1}

local router={generic={}, accurate={}, version=0}

function _M.new(routes)
	for _, route in pairs(routes) do
		local h = route.domain or ""
		if str_sub(h, 1, 1) ~= "*" then
			tab_insert(router.accurate, route)
		else
			tab_insert(router.generic, route)
		end
	end

	router.version = routes["_version"]

	ngx_log(DEBUG, "routes: ", encode(routes), ", router: ", encode(router), ", version: ", router.version)
end

function _M.init()
	local update = function(premature)
		if premature then return end

		local routes = get_route()
		local ver = routes["_version"]

		if not router or ver ~= router.version then
			ngx_log(INFO, "update router. version: ", ver)
			_M.new(routes)
		end
	end

	update()
	local ok, err = ngx_timer_every(3, update)
	if not ok then
		ngx_log(ERR, err)
	end

	ngx_log(INFO, "route init.")
end

local function match_host(host, domain)
	if not domain or domain == "" or host == domain then
		return true
	end

	if str_sub(domain, 1, 1) == "*" then
		local d = str_sub(domain, 2)
		if str_match(host, d) then
			return true
		end
	end

	return false
end

local function match_methods(method, methods)
	if not methods or #methods == 0 then
		return true
	end

	for _, m in ipairs(methods) do
		if m == method then
			return true
		end
	end

	return false
end

local function match_uri(uri, regular)
	if regular == "" or ngx_match(uri, regular, "jo") then
		return true
	else
		return false
	end
end

function _M.match(host, method, uri)
	local f = function(routes)
		for _, route in ipairs(routes) do
			local domain = route.domain

			if match_host(host, domain) then
				for _, item in ipairs(route.items) do
					local methods = item.methods
					local re_uri = item.uri

				    if match_methods(method, methods) and match_uri(uri, re_uri) then
						return route, item
					end
				end
			end
		end
	end

	local rt, it = f(router.accurate)
	if rt then
		return rt, it
	else
		return f(router.generic)
	end
end

return _M
