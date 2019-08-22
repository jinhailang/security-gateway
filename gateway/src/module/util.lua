local uuid = require "resty.jit-uuid"
local cjson  = require("cjson.safe")

local gen_id_v4 = uuid.generate_v4
local ngx_exit = ngx.exit
local ngx_print = ngx.print
local str_find = string.find
local str_sub = string.sub

local get_headers = ngx.req.get_headers

local _M = {version = 0.1}


function _M.exit_pass()
	ngx.header["Content-Type"] = "application/json"
	ngx_print('{"code": 0, "msg": "pass"}')

	return ngx_exit(200)
end

function _M.exit_block()
	ngx.header["Content-Type"] = "application/json"
	ngx.status = 403

	ngx_print('{"code": 403, "msg": "block"}')
	return ngx_exit(403)
end


function _M.parse_addr(addr)
	local pos = str_find(addr, ":", 1, true)
	if not pos then
		return addr, 80
	end

	local port = str_sub(addr, pos + 1)
	return str_sub(addr, 1, pos - 1), tonumber(port)
end

function _M.get_headers_value(key)
	local headers = get_headers()

	if type(headers) ~= "table" then
		return
	end

	local v = headers[key]
	if type(v) == "table" then
		return v[1]
	else
		return v
	end
end

function _M.gen_id()
	return gen_id_v4()
end

-- common method for api response
function _M.out_err(msg, status)
    local data

    if type(msg) == "table" then
        data = cjson.encode(msg)
    else
        data = msg
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.status = status or ngx.HTTP_INTERNAL_SERVER_ERROR

    ngx.print(data)
    ngx.exit(ngx.status)
end
-- common method for api response
function _M.out_ok(msg)
    local data

    if type(msg) == "table" then
        data = cjson.encode(msg)
    else
        data = msg
    end

    ngx.header["Content-Type"] = "application/json"
    ngx.status = ngx.HTTP_OK

    ngx.print(data)
    ngx.exit(ngx.status)
end

return _M
