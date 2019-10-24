
local resty_lock = require "resty.lock"

local lock, err = resty_lock:new("cache_lock")
if not lock then
    fail("failed to create lock: ", err)
end

local elapsed, err = lock:lock("my_key")
if not elapsed then
    ngx.log(ngx.ERR, "failed to acquire the lock: ", err)
    return 
end

ngx.sleep(1)

local ok, err = lock:unlock()
if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", err)
    return 
end

