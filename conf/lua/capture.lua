
local res1,res2,res3,res4 = ngx.location.capture_multi{
    {"/mysql_test", {args="t=1&id=1"}},
    {"/redis_test", {args="t=2&id=2"}},
    {"/lua", {args="t=3&id=3"}},
    {"/index.php", {args="t=3&id=3"}},
}

ngx.header.content_type="text/plain"
ngx.say(res1.body)
ngx.say(res2.body)
ngx.say(res3.body)
ngx.say(res4.truncated)
ngx.say(res4.status)
ngx.say(res4.header["Set-Cookie"])

ngx.say(res4.body)

