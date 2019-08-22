local events = require "resty.worker.events"
local etcd = require "etcd"
local route = require "route"
local log = require "logger"
local uuid = require "resty.jit-uuid"

local ngx_log = ngx.log
local ERR = ngx.ERR


-- init uuid
uuid.seed()

-- init worker event
local ok, err = events.configure({shm = "events", interval = 0.1})
if not ok then
	ngx_log(ERR, "failed to start event system: ", err)
end

ok, err = ngx.timer.at(0, etcd.init)
if not ok then
	ngx_log(ERR, "etcd init error: " .. err)
end

route.init()

ok, err = ngx.timer.at(0, log.init)
if not ok then
	ngx_log(ERR, "log init error: " .. err)
end




