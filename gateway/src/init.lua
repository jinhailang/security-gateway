require "resty.core"
local config = require "config"
local global = require "global"

local ngx_ERR  = ngx.ERR
local ngx_INFO = ngx.INFO
local ngx_log  = ngx.log
local ngx_WARN = ngx.WARN


ngx_log(ngx_WARN, global.get_vn())

global.update_start_time()

local err = config.load_config()
if err ~= nil then
    ngx_log(ngx_ERR, "load system config error: ", err)
else
    ngx_log(ngx_INFO, "load sysytem config success.")
end
