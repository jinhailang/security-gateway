local etcd      = require "etcd"
local cjson     = require("cjson.safe")
local utils     =  require "util"

local out_err        = utils.out_err
local out_ok         = utils.out_ok
local gsub           = string.gsub
local ssub           = string.sub
local sfind          = string.find
local get_method     = ngx.req.get_method
local get_args       = ngx.req.get_uri_args

local ngxLogInfo     = ngx.log
local ERR            = ngx.ERR
local INFO           = ngx.INFO
local str_format     = string.format

local cfg_service_key   = "/service/%s"
local cfg_route_key     = "/route/%s"

-- rest api for service
local service_api = {
    -- get one or get all when serviceID is nil
	GET = function(servcieID)
		local args       = get_args() or {}
        local servcieID  = servcieID or args["service_id"]  or ""
        local serviceMap = etcd.get_service()
        -- get all
        if servcieID == "" then
            return out_ok({code=200, msg="ok", data=serviceMap})
        end
        -- get one
        if not serviceMap then
            return out_err({code=100404002, msg="service config is empty"})
        end

        return out_ok({code=200, msg="ok", data=serviceMap[servcieID]})
	end,
    -- create one
    PUT = function(servcieID)
        ngx.req.read_body()

        -- servcieID must be exist
        local serviceID  = servcieID or ""
        if serviceID == "" then
            return out_err({code=100404002, msg="request service_id is empty"})
        end
        
        local data = ngx.req.get_body_data() or ""
        if data == "" then
            return out_err({code=100404002, msg="request body is empty for service_id " .. servcieID})
        end

        local body, errr = cjson.decode(data)
        if errr then
            errr = str_format("decode service config=%s error: %s", data, errr)
            ngxLogInfo(ERR, errr)
            return out_err({code=100500002, msg=errr})
        end

        local val, errr = etcd.set(str_format(cfg_service_key,serviceID), body)
		if errr then
            errr = str_format("set service config error: %s", errr)
            ngxLogInfo(ERR, errr)

			return out_err({code=100500002, msg=errr})
        end
        
        return out_ok({code=200, msg="ok", data=val})
	end,
    -- del one
    DELETE = function(serviceID)
		local args = get_args() or {}
		local serviceID  = serviceID or args["service_id"] or ""

        if serviceID == "" then
            return out_err({code=100404002, msg="request service_id is empty"})
        end

        local _, errr = etcd.delete(str_format(cfg_service_key,serviceID))
		if errr then
            errr = str_format("delete service config error: %s, service_id: %s", errr, serviceID)
            ngxLogInfo(ERR, errr)
			return out_err({code=100500005, msg=errr})		
        end

        return out_ok({code=200, msg="ok"})
	end,

}
-- rest api for route
local route_api = {
    -- get one or get all when rTableID is nil
	GET = function(rTableID)
		local args = get_args() or {}
        local rid  = rTableID or args["id"]  or ""
        local  routeMap = etcd.get_route()
        -- get all
        if rid == "" then
            return out_ok({code=200, msg="ok", data=routeMap})
        end
        -- get one
        if not routeMap then
            return out_err({code=100404002, msg="route config is empty"})
        end

		return out_ok({code=200, msg="ok", data=routeMap[rid]})
	end,
    -- create one
    PUT = function(rid)
        ngx.req.read_body()

        -- rid must be exist
        local rid = rid or ""
        if rid == "" then
            return out_err({code=100404002, msg="request route id is empty"})
        end

        local data = ngx.req.get_body_data() or ""
        if data == "" then
            return out_err({code=100404002, msg="request body is empty for rid " .. rid})
        end

        local body, errr = cjson.decode(data)
        if errr then
            errr = str_format("decode route config=%s error: %s", data, errr)
            ngxLogInfo(ERR, errr)
            return out_err({code=100500002, msg=errr})
        end

        local val, errr = etcd.set(str_format(cfg_route_key,rid), body)
		if errr then
            errr = str_format("set route config error: %s", errr)
            ngxLogInfo(ERR, errr)

			return out_err({code=100500002, msg=errr})
        end
        
        return out_ok({code=200, msg="ok", data=val})
	end,
    -- del one
    DELETE = function(rid)
		local args = get_args() or {}
		local rid  = rid or args["id"] or ""

        if rid == "" then
            return out_err({code=100404002, msg="request route id is empty"})
        end

        local _, errr = etcd.delete(str_format(cfg_route_key,rid))
		if errr then
            errr = str_format("delete route config error: %s, id: %s", errr, rid)
            ngxLogInfo(ERR, errr)
			return out_err({code="100500005", msg=errr})
        end

        return out_ok({code=0, msg="ok"})
	end,

}


local api_funcs = {
    ["_config_service"] = service_api,
    ["_config_route"] = route_api,
}

-- api rest entrypoint
local method = get_method()
local uri    = ngx.var.uri

local api_key, _ = gsub(uri, "/", "_")
local  reqId = "";

for key, item in pairs(api_funcs) do
    -- match 
    if api_key == key then
        break;
    else
        local fst = sfind(api_key,key)
        if fst then
            reqId = ssub(api_key, #key+fst+1) or ""
            if tonumber(reqId) then
                api_key = key
                break;
            end
        end
    end
end   

-- access log
ngxLogInfo(INFO, str_format("uri:%s,method:%s,id:%s, api_key:%s",uri,method,reqId,api_key))

local  func = api_funcs[api_key];
if not func then
    return out_err({code="100404001", msg=uri .. " not found."}, 404)
else
    local exec = func[method]
    if not exec then
        return out_err({code=100404002, msg=method .. " methods are not supported."}, 404)
    end
    return exec(reqId)
end

