local config = require "config"
local etcd = require "resty.etcd"
local tab_clone  = require "table.clone"
local cjson = require "cjson"

local encode       = cjson.encode
local ngx_log      = ngx.log
local ERR          = ngx.ERR
local INFO         = ngx.INFO
local DEBUG        = ngx.DEBUG
local str_sub      = string.sub
local ngx_timer_at = ngx.timer.at
local get_cfg      = config.get_cfg
local random       = math.random

local _M = {version = 0.1}
_M["config"] = {}

local etcd_cfg = _M["config"]


local function new()
    local conf = get_cfg()
    if not conf then
        return nil, nil,"etcd config is nil."
    end

    local etcd_conf = tab_clone(conf.etcd)
    local prefix = etcd_conf.prefix or ""
    etcd_conf.prefix = nil

	local ln = #etcd_conf.endpoints
	local index = random(1, ln)

	etcd_conf.timeout = etcd_conf.timeout * 1000
	etcd_conf.host = etcd_conf.endpoints[index]
    local etcd_cli, err

    etcd_cli, err = etcd.new(etcd_conf)
    if not etcd_cli then
        return nil, nil, err
    end

    return etcd_cli, prefix
end
_M.new = new

function _M.get(key)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:get(prefix .. key)
end

function _M.set(key, value)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:set(prefix .. key, value)
end

function _M.delete(key)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:delete(prefix .. key)
end

function _M.server_version(key)
    local etcd_cli, err = new()
    if not etcd_cli then
        return nil, err
    end

    return etcd_cli:version()
end

local function waitdir(key, index)
    local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

	local data
	data, err = etcd_cli:waitdir(prefix .. key, index)
	if not data then
		return nil, nil, err
	end

	local body = data.body
	if type(body) ~= "table" then
		return nil, nil, "failed to read etcd dir"
	end

	if body.message then
		return nil, nil, body.message
	end

	return body.node, data.headers["X-Etcd-Index"]
end

local function readdir(key)
	ngx_log(INFO, "readdir key: " .. key)

	local etcd_cli, prefix, err = new()
    if not etcd_cli then
        return nil, err
    end

	local data
	data, err = etcd_cli:readdir(prefix .. key, true)
	if not data then
		return nil, nil, err
	end

	local body = data.body
	if type(body) ~= "table" then
		return nil, nil, "failed to read etcd dir"
	end

	if body.message then
		return nil, nil, body.message
	end

	return body.node, data.headers["X-Etcd-Index"]
end

local function parse_key(dir_key, key)
	local etcd_conf = get_cfg().etcd or {}
	local prefix = etcd_conf.prefix or ""
	dir_key = prefix .. dir_key

	return str_sub(key, #dir_key + 2)
end

function _M.wait(premature, key, index)
	if premature then
		 return
	end
	local node, etcd_index, err = waitdir(key, index)
	if err then
		return err
	end

	if not node then
		return "node is nil"
	end

	local sub_key = parse_key(key, node["key"])
	local value = node["value"]
	local tb = etcd_cfg[key]

	tb[sub_key] = value
	tb:_update_version()

	ngx_log(INFO, "etcd data update. key: ", key, ", sub_key: ", sub_key, ", value: ", encode(value))

	local ok, err = ngx_timer_at(0, _M.wait, key, etcd_index + 1)
	if not ok then
		ngx_log(ERR, err)
		return err
	end
end

local config_keys = {
	service = "/service",
	route = "/route",
}

function _M.init()
	local auto = function(key)
		local node, index, err = readdir(key)
		if err then
			return err
		end

		if not node then
			return "node is nil"
		end

		local tb = etcd_cfg[key] or {}
		local st = {_version=1, _update_version=function(self) self._version=self._version+1 end}

		setmetatable(tb, {__index = st,
	                      __newindex = function(mytable, key, value)
						                   if key== "_version" then
						                       st._version = value
										   else
											   rawset(mytable, key, value)
										   end
									   end,
						 }
					)
		local nodes = node["nodes"] or {}
		for _, item in ipairs(nodes) do
			local sub_key = parse_key(key, item["key"])
			local value = item["value"]

			tb[sub_key] = value
		end

		etcd_cfg[key] = tb
		local _, err = ngx_timer_at(0, _M.wait, key, index + 1)
		return err
	end

	for _, v in pairs(config_keys) do
		local err = auto(v)
		if err then
			ngx_log(ERR, "auto error: " .. err)
		end
	end

	ngx_log(DEBUG, "etcd config: ", encode(etcd_cfg))
	ngx_log(INFO, "etcd init finish.")
end

local function get(name)
	return etcd_cfg[name] or {}
end

function _M.get_route()
	return get(config_keys.route)
end

function _M.get_service()
	return get(config_keys.service)
end


return _M
