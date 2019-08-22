local _M = {}

local now = ngx.localtime

_M.sys_version          = "v1.0.0"
_M.sys_name             = "security-gateway"
_M.sys_start_time       = 0

function _M.get_vn()
    return _M.sys_name .. "/" .. _M.sys_version
end

function _M.update_start_time()
    _M.sys_start_time = now()
end

function _M.get_start_time()
     return _M.sys_start_time
end

return _M

