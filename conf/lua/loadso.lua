local constants = require "kong.constants"
local singletons = require "kong.singletons"
local cjson = require "cjson"
local utils = require "kong.tools.utils"
local responses = require "kong.tools.responses"
local message = require("kong.jcloud.util.log").message
local gwstatus = require "kong.jcloud.util.gwstatus"
local ffi = require("ffi")
local log = ngx.log
local ERROR = ngx.ERR
local INFO = ngx.INFO
local WARN = ngx.WARN

local ngx_req_read_body = ngx.req.read_body
local ngx_req_get_body_data = ngx.req.get_body_data
local ngx_get_headers = ngx.req.get_headers
local _M={}
local WAF_MATCH_OK=0
local WAF_MATCH_ERR=-1

local PARAM_HDR_TYPE=0
local PARAM_VAR_TYPE=1
local PARAM_MZ_TYPE=2

local WAF_PHASE_REQ=1
local WAF_PHASE_REQ_HEADER=2
local WAF_PHASE_REQ_BODY=3
local WAF_PHASE_RESP=4
local WAF_PHASE_RESP_HEADER=5
local WAF_PHASE_RESP_BODY=6


local WAF_NOT_MATCH=0
local WAF_MATCHED=1
local WAF_MATCHING=2
local WAF_NOT_FOUND=3

local myffi=ffi.load("/gitroot/jd/vpcwaf-sdk/lib/libhps.so") --lua 数组映射到C层
ffi.cdef[[
          void * waf_init(const char *waf_config_name, const char *logfile);
          int waf_init_mz_mapping_default(void *waf);
          void waf_fini(void *waf_handler);
          int waf_get_commit_id();
          void waf_data_destroy(void *waf_data);

          typedef enum {
              WAF_PHASE_REQ = 1,
              WAF_PHASE_REQ_HEADER,
              WAF_PHASE_REQ_BODY,
              WAF_PHASE_RESP, /* 3 */
              WAF_PHASE_RESP_HEADER,
              WAF_PHASE_RESP_BODY
          } waf_phase_e;


          typedef struct {
              int rule_id;
              char *start;
              unsigned int from;
              unsigned int to;
          /* 需要拷贝， 因为可能存在多个chain,
          * 如果不拷贝在下一个chain会丢失当前的指针 */
              unsigned char *payload;
              unsigned int payload_len;
              waf_phase_e phase;
          } rule_result_t;


          typedef struct {
              int policy_id;
              int policy_action;
              //char policy_action[64];
              rule_result_t *results[64]; /* point to rules[i] */
              int cursor;
              int match_state; /* WAF_NOT_MATCH WAF_MATCHING WAF_MATCHED */
              waf_phase_e phase;
          } policy_result_t;


          /* 语义解析结果集 */
          typedef struct {
              int action;
              //char action[64];
              char mz[64];
              char fingerprint[8];
              unsigned char payload[50];
              unsigned int payload_len;
              waf_phase_e phase;
          } sa_result_t;

          typedef struct {
             rule_result_t *rule_results[64];
             int rule_cursor;
             policy_result_t *policy_results;
             int policy_cursor;
             policy_result_t **policy_hit_results;
             int policy_hit_cursor;
             sa_result_t *sa_results[64];
             int sa_cursor;
          } match_result_t;




          typedef struct {
              char *data;
              size_t dlen;
              int is_copy;
              unsigned int hash;
              int self_clone;
              unsigned int matched;
              int init_result;
              match_result_t *result;
          } match_data_t;

          match_data_t * waf_match_data_alloc( unsigned char *data, size_t dlen, int is_copy, int init_result, int self_clone);

          void * waf_data_create_default(
              int have_body,
              match_data_t *method,
              match_data_t *uri,
              match_data_t *args,
              match_data_t *cookies,
              match_data_t *request_body,
              match_data_t *request_uri,
              match_data_t *user_agent,
              match_data_t *referer,
              match_data_t *url);

          int waf_data_add_param(void *waf_data, int type, match_data_t *key, match_data_t *value);

          /* FUNCTION: WAF match
           * @phase:
           * 如果: header + body 一次性传入， 则phase WAF_PHASE_ANY
           * 否则：
           * header阶段传入WAF_PHASE_HEADER
           * body阶段传入WAF_PHASE_BODY
           * */
          int waf_match(void *waf_handler, void *waf_mctx, void *waf_data, waf_phase_e phase);

          /* FUNCTION: return match result */
          match_result_t *waf_match_result_get(void *waf_data);
      ]]

--local config_json="/usr/local/share/lua/5.1/kong/plugins/waf/hpslib.json"
local config_json="/root/myresty/conf/waf2.dat"
local log_path="/tmp/waf_log.log"
local log_str=ffi.string(log_path)
local waf
local waf_data

local function wafDataConvert(str,type)
    if str==nil or str==ngx.null then
        str=""
    end
    local request_param=str
    local req_param=ffi.cast("unsigned char *",request_param)
    local request_param_len=ffi.new("size_t",#request_param)
    local md_param
    if type=="key" then
        md_param=myffi.waf_match_data_alloc(req_param,request_param_len,0, 0, 1)
    elseif type=="value" then
        md_param=myffi.waf_match_data_alloc(req_param,request_param_len,0, 1, 1)
    end
    return md_param
end

local function destoryWafData(logMessage)
    if logMessage then
        log(INFO,logMessage)
    end
    if waf_data then
        log(INFO,"waf_match_data_free ok!")
        myffi.waf_data_destroy(waf_data)
    end
    log(INFO,"waf_fini ok!")
    myffi.waf_fini(waf);
end



function _M.execute(conf)

    waf=myffi.waf_init (config_json, ngx.null)
    log(INFO,myffi.waf_get_commit_id())
    log(INFO,"waf_init ok!")
    if waf == nil then
        destoryWafData("Error: init")
    end
    if myffi.waf_init_mz_mapping_default(waf) == WAF_MATCH_ERR then
        destoryWafData("waf_init_mz_mapping_default error!")
    end
    log(INFO,"waf_init_mz_mapping_default ok!")

    ngx_req_read_body()
    local bodyjson = ngx_req_get_body_data()
    local path = ngx.unescape_uri(ngx.var.uri)
    local query_string = ngx.var.query_string
    local req_method=ngx.var.request_method
    local user_agent=ngx.var.http_user_agent
    local cookies=ngx.var.http_cookie
    local referer=ngx.var.http_referer
    local req_uri=ngx.var.request_uri
    local host=ngx.var.host
    local scheme=ngx.var.scheme
    local port=ngx.var.server_port

    log(INFO,"========req_method :"..req_method.." path param :"..path.."\n")
    log(INFO,"========req_args: "..tostring(query_string).." cookies: "..tostring(cookies).."\n")
    log(INFO,"========body: "..tostring(bodyjson).." user_agent: "..tostring(user_agent).."\n")
    log(INFO,"========referer: "..tostring(referer).." request_uri: "..tostring(req_uri).."\n")
    log(INFO,"========host: "..tostring(host).." scheme: "..tostring(scheme).."\n")


    local host_header do
        local with_port
        if scheme == "http" then
            with_port=port~=80
        elseif scheme=="https" then
            with_port = port ~= 443
        end

        if with_port then
            host_header = string.format("%s:%d", host, port)
        else
            host_header = host
        end
    end
    local url = scheme .. "://" .. host_header .. req_uri
    log(INFO,url)

    local md_method=wafDataConvert(req_method,"value")
    local md_uri=wafDataConvert(path,"value")
    local md_args=wafDataConvert(query_string,"value")
    local md_cookies=wafDataConvert(cookies,"value")
    local md_body=wafDataConvert(bodyjson,"value")
    local md_request_uri=wafDataConvert(req_uri,"value")
    local md_user_agent=wafDataConvert(user_agent,"value")
    local md_referer=wafDataConvert(referer,"value")
    local md_url=wafDataConvert(url,"value")
    waf_data=myffi.waf_data_create_default(
            0,
            md_method,
            md_uri,
            md_args,
            md_cookies,
            md_body,
            md_request_uri,
            md_user_agent,
            md_referer,
            md_url);

    if waf_data == nil or waf_data==ngx.null then
        log(INFO,"waf_data_create_default error!\n")
        destoryWafData()
    end


    log(INFO,"waf_data_create_default ok!\n")


    -- add headers
    local headers = ngx_get_headers()
    local filterHeaders = {}
    local HeaderFilter = {
        ["x-original-to"] = true,
        ["x-jdlb-client-port"] = true,
    }
    local header_key
    local header_value
    for k,v in pairs(headers) do
        local filter = false
        if HeaderFilter[k] then
            filter = true
        else
            local i,_ = string.find(k,"x-jcloud-")
            if i then
                filter = true
            end
        end
        if not filter then
            filterHeaders[k] = v
        end

        header_key=wafDataConvert(k,"key")
        if header_key == ngx.NULL or header_key==nil then
            destoryWafData("content_type_key")
        end
        header_value=wafDataConvert(v,"value")
        if header_value == ngx.NULL or header_value==nil then
            destoryWafData("content_type_value")
        end
        log(INFO,tostring(k).." :"..tostring(v))

        if myffi.waf_data_add_param(waf_data,PARAM_HDR_TYPE,header_key,header_value)==WAF_MATCH_ERR then
            destoryWafData("waf_data_add_param")
        end


    end
    log(INFO,"waf_data_add_header ok!\n")





--[[    local key=wafDataConvert("Content-Type","key")

    if key == ngx.NULL or key==nil then
        destoryWafData("content_type_key")
    end



    local value=wafDataConvert("application/x-www-form-urlencoded","value")
    if value == ngx.NULL or value==nil then
        destoryWafData("content_type_value")
    end


    if myffi.waf_data_add_param(waf_data,PARAM_HDR_TYPE,key,value)==WAF_MATCH_ERR then
        destoryWafData("waf_data_add_param")
    end
    log(INFO,"waf_data_add_param ok!\n")]]


    -- match waf data


    if myffi.waf_match(waf,ngx.null,waf_data,WAF_PHASE_REQ_HEADER)==WAF_MATCH_ERR then
        destoryWafData("waf_match")
    end
    log(INFO,"waf_match ok!")


    -- check hit
    local mr
    mr=myffi.waf_match_result_get(waf_data)
    if mr==nil then
        log(INFO,"not hit policy")
    else
        log(INFO,"==============sa_cursor:"..mr.sa_cursor .." policy_cursor:"..mr.policy_cursor.."================")
    end

    --check sa hit
    if mr.sa_cursor>0 then
        log(INFO,"hit SA")
        local s
        for i=0,mr.sa_cursor-1 do
            s=mr.sa_results[i]
            if s~=nil and s~=ngx.null then
                log(INFO,"==============fingerprint:"..s.fingerprint.." mz:"..s.mz.." action:"..s.action.."================")
            end
        end
    else
        log(INFO,"not hit SA")
    end

    --check policy hit

    if mr.policy_hit_cursor>0 then
        local p
        for i=0,mr.policy_hit_cursor-1 do
            p=mr.policy_hit_results[i]
            if p~=ngx.null and p~=nil and  p.match_state==WAF_MATCHED then

                log(INFO,"==============hit policyid:"..p.policy_id.." action:"..p.policy_id.."================")
                local ru
                for j=0,p.cursor-1 do
                    ru=p.results[j]
                    local payload_str=ffi.string(ru.payload)
                    log(INFO,"===========hit rule:"..ru.rule_id.." payload:"..payload_str.." payload_len:"..ru.payload_len.."================")
                end
            end
        end
    end

    --destoryWafData()
    if waf_data then
        log(INFO,"waf_match_data_free ok!")
        myffi.waf_data_destroy(waf_data)
    end
    myffi.waf_fini(waf);
    log(INFO,"waf_fini ok!")

end
return _M
