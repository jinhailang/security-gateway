local cjson = require "cjson"

local io_open   = io.open
local ngx_md5   = ngx.md5
local ngx_ERR   = ngx.ERR
local ngx_log   = ngx.log
local ngx_INFO  = ngx.INFO
local format    = string.format

local CONFIG_PATH = "/opt/gateway/conf/sys.json"

local _M = {version = 0.1}
_M["config"] = {}

local function load_file(file_path)
	local file = io_open(file_path, "r")
    if file == nil then
		return nil, "file not found."
    end

    local data = file:read("*all")
	file:close()

    local cfg_temp = cjson.decode(data)
    if type(cfg_temp) ~= "table" then
		return nil, "file data decode error."
    end

    local cfg_hash = ngx_md5(data)

	return {ddata=cfg_temp, hash=cfg_hash}
end

function _M.load_config(file_path)
	if type(file_path) ~= "string" then
		file_path = CONFIG_PATH
	end

    ngx_log(ngx_INFO, "load config. path: ", file_path)
	local rs, err = load_file(file_path)
	if err then
		ngx_log(ngx_ERR, "load config error: ", err)
		return err
	end

	local cfg_hash = rs.hash
	_M["config"]  = rs.ddata

    ngx_log(ngx_INFO, format("the config loaded successfully. file_path: %s, hash: %s", file_path, cfg_hash))
	return nil
end

function _M.get_cfg()
	return _M["config"]
end

return _M
