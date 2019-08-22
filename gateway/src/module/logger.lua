local logger = require "resty.logger.socket"
local config = require "config"
local cjson = require "cjson"

local encode = cjson.encode
local get_cfg = config.get_cfg
local ngx_log = ngx.log
local ERR = ngx.ERR
local DEBUG = ngx.DEBUG

local _M = {version = 0.1}

local default_host = "127.0.0.1"
local default_port = 1234


local function init()
	local cfg = get_cfg() or {}
	local log_cfg = cfg.log or {}

	local ok, err = logger.init{
		sock_type = 'tcp',
        host = log_cfg.host or default_host,
        port = log_cfg.port or default_port,
        flush_limit = 32,
        drop_limit = 1048576,
        periodic_flush = 1,
    }

	if not ok then
		ngx_log(ERR, "failed to initialize the logger: ", err)
		return err
	end

	return
end

_M.init = init

local function write(data)
	if type(data) ~= "string" then
		data = tostring(data)
	end

	if data == nil or #data == 0 then
		return
	end

	if not logger.initted() then
		init()
	end

	local bytes, err = logger.log(data)
	if err ~= nil then
		ngx_log(ERR, "failed to log message: ", err)
	elseif bytes == 0 then
		ngx_log(ERR, "bytes is 0, worker is exiting or over drop_limit. will retry!")

		bytes, err = logger.log(data)
		if bytes == 0 or err ~= nil then
			ngx_log(ERR, "tetry failed to log message: ", err or "")
		end
	end

	return err
end

function _M.send(msg, typ)
	local m = {}
	m["msg"] = msg or {}
	m["type"] = typ or ""

	local data = encode(m)
	if data then
		ngx_log(DEBUG, "log send data: " .. data)
		return write(data .. '\n')
	end

	return
end


return _M
