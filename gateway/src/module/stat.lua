local config = require "config"
local etcd = require "etcd"
local logger = require "logger"

local log_send = logger.send
local get_cfg = config.get_cfg
local get_route = etcd.get_route
local get_service = etcd.get_service
local time        = ngx.time
local log         = ngx.log
local ERR         = ngx.ERR

local _REFRESH_KEY_ = "__REFRESH__"
local _ALL_REQ_  = "_gateway_all_"
local _ROUTE_REQ_SUF  = "_route_"
local _SERVICE_REQ_SUF = "_service_"

local _M = {version = 0.1}

local function refresh(premature, period)
    if premature then
        return
    end

    if period < 1 then
        period = 1
    end

    local shared_stat = ngx.shared.stat_req
    local routes = get_route() or {}
    local services = get_service() or {}
	local tm = time()

	-- refresh all request statistics
	local key = _ALL_REQ_
	local qps={timestamp=tm, req_cnt=0}

	local cnt, err = shared_stat:get(key)
	if err then
		log(ERR, err)
	end

	shared_stat:delete(key)
	qps.req_cnt = cnt or 0
	log_send(qps, "qps")

	-- refresh route request statistics
    for rid, _ in pairs(routes) do
		local qps_route={rt_id=rid, timestamp=tm, req_cnt=0}
        key = rid .. _ROUTE_REQ_SUF

        cnt, err = shared_stat:get(key)
        if err then
            log(ERR, err)
		end

		shared_stat:delete(key)
		qps_route.req_cnt = cnt or 0

		log_send(qps_route, "qps_route")
	end

	-- refresh service request statistics
    for sid, _ in pairs(services) do
		local qps_sub={service_id=sid, timestamp=tm, req_cnt=0}
        key = sid .. _SERVICE_REQ_SUF

        cnt, err = shared_stat:get(key)
        if err then
            log(ERR, err)
		end

		shared_stat:delete(key)
		qps_sub.req_cnt = cnt or 0

		log_send(qps_sub, "qps_sub")
	end

    shared_stat:set(_REFRESH_KEY_, true, period * 5)
end

local function check()
    local shared_stat = ngx.shared.stat_req
    local cfg = get_cfg()
    local period = cfg.stat_period or 5

    local ok, _ = shared_stat:add(_REFRESH_KEY_, true, period * 5)
    if ok then
        local ok, err = ngx.timer.every(period, refresh, period)
        if not ok then
            log(ERR, "failed to create timer: ", err)
            return
        end
    end
end

function _M.stat_all()
	check()

    local shared_stat = ngx.shared.stat_req

    local _, err = shared_stat:incr(_ALL_REQ_, 1, 0)
    if err then
        log(ERR, err)
    end

    return
end

function _M.stat_route(route_id)
	check()

    local shared_stat = ngx.shared.stat_req

    local _, err = shared_stat:incr(route_id .. _ROUTE_REQ_SUF, 1, 0)
    if err then
        log(ERR, err)
    end

    return
end

function _M.stat_service(service_id)
	check()

    local shared_stat = ngx.shared.stat_req

    local _, err = shared_stat:incr(service_id .. _SERVICE_REQ_SUF, 1, 0)
    if err then
        log(ERR, err)
    end

    return
end


return _M
