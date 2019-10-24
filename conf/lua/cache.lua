
local redis = require "resty.redis"
local red = redis:new()

function set_to_cache(key, value, exptime)
    if not exptime then
        exptime = 0
    end
    local ngx_cache = ngx.shared.ngx_cache
    local succ, err, forcible = ngx_cache:set(key, value, exptime)
    return succ
end

function get_from_cache(key)
    local ngx_cache = ngx.shared.ngx_cache;
    local value = ngx_cache:get(key)
    if not value then
        value = get_from_redis(key)
        set_to_cache(key, value)
        return value
    end

    ngx.say("get from cache.")
    return value
end

function get_from_redis(key)
    red:set_timeout(1000)

    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    local res, err = red:get(key)
    if not res then
        ngx.say("failed to get doy: ", err)
        return ngx.null
    end

    ngx.say("get from redis.")
    return res
end

function set_to_redis(key, value)
    red:set_timeout(1000)
    local ok, err = red:connect("127.0.0.1", 6379)
    if not ok then
        ngx.say("failed to connect: ", err)
        return
    end

    local ok, err = red:set(key, value)
    if not ok then
        ngx.say("failed to set to redis: ", err)
        return
    end
    return ok
end

set_to_redis('dog', "Bob")
local rs = get_from_cache('dog')
ngx.say(rs)

