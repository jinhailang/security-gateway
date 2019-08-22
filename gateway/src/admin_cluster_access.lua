local utils     =  require "util"

local out_err       = utils.out_err
local out_ok        = utils.out_ok

local gsub           = string.gsub
local get_method     = ngx.req.get_method
local ngxLogInfo     = ngx.log
local ERR            = ngx.ERR
local INFO           = ngx.INFO

-- rest api for system
local node_info_api = {
	GET = function()
		local rt = {
            nodes =  {"127.0.0.1:80"}
        }
		return out_ok(rt)
	end
}

local node_config_api = {
    GET = function()
        -- todo
		local rt = {
            nodes = {"127.0.0.1:80"}
        }
		return out_ok(rt)
	end
}

local node_status_api = {
	GET = function()
		return out_ok({code = 200, msg="ok"})
	end
}

local api_funcs = {
    ["_cluster_node"]   = node_info_api,
    ["_cluster_config"] = node_config_api,
    ["_cluster_status"] = node_status_api,
}

-- api rest entrypoint
local method = get_method()
local uri    = ngx.var.uri

-- access-log
ngxLogInfo(INFO, string.format( "uri:%s,method:%s",uri,method))

local api_key, _ = gsub(uri, "/", "_")
local func = api_funcs[api_key]

if not func then
    return out_err({code="100404001", msg=uri .. " not found."}, 200)
else
    local exec = func[method]
    if not exec then
        return out_err({code="100404002", msg=method .. " methods are not supported."}, 200)
    end

    return exec()
end