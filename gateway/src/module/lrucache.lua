-- Copyright (C) Yuansheng Wang

local lru_new = require("resty.lrucache").new
local setmetatable = setmetatable
local getmetatable = getmetatable
local type = type

local GLOBAL_ITEMS_COUNT= 1024
local GLOBAL_TTL        = 60 * 60          -- 60 min
local lua_metatab = {}


local function new_lru_fun(opts)
    local item_count = opts and opts.count or GLOBAL_ITEMS_COUNT
    local item_ttl = opts and opts.ttl or GLOBAL_TTL
    local item_release = opts and opts.release
    local lru_obj = lru_new(item_count)

    return function (key, version, create_obj_fun, ...)
        local obj, stale_obj = lru_obj:get(key)
        if obj and obj._cache_ver == version then
            local met_tab = getmetatable(obj)
            if met_tab ~= lua_metatab then
                return obj
            end

            return obj.val
        end

        if stale_obj and stale_obj._cache_ver == version then
            lru_obj:set(key, stale_obj, item_ttl)

            local met_tab = getmetatable(stale_obj)
            if met_tab ~= lua_metatab then
                return stale_obj
            end

            return stale_obj.val
        end

        if item_release and obj then
            item_release(obj)
        end

        local err
        obj, err = create_obj_fun(...)
        if type(obj) == 'table' then
            obj._cache_ver = version
            lru_obj:set(key, obj, item_ttl)

        elseif obj ~= nil then
            local cached_obj = setmetatable({val = obj, _cache_ver = version},
                                            lua_metatab)
            lru_obj:set(key, cached_obj, item_ttl)
        end

        return obj, err
    end
end

local _M = {
    version = 0.1,
    new = new_lru_fun,
}


return _M
