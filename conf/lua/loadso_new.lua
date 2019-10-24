 local ffi = require("ffi")
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
      --local myffi=ffi.load("/usr/lib/waf/libhps_old.so") --lua 数组映射到C层
      local myffi=ffi.load("/gitroot/jd/vpcwaf-sdk/lib/libhps.so") --lua 数组映射到C层
      --local myffi=ffi.load("../waf/libhps_old.so") --lua 数组映射到C层
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
      log(INFO,myffi.waf_get_commit_id())
      log(INFO,"waf_init ok!")
      local config_json="/root/myresty/conf/waf2.dat"
      local log_path="/tmp/waf_log.log"
      local conf_str=ffi.string(config_json)
      local log_str=ffi.string(log_path)
      local waf=myffi.waf_init (config_json, log_str)
      --local waf=myffi.waf_init ("/usr/local/openresty/lualib/hpslib.json", ngx.NULL)
      log(INFO,"waf_init ok!")
      if waf == nil then
        log(INFO,"Error: init")
        myffi.waf_fini(waf)
        --return false
      end
      log(INFO,"===="..tostring(waf))
      if myffi.waf_init_mz_mapping_default(waf) == WAF_MATCH_ERR then
        log(INFO,"waf_init_mz_mapping_default error!")
        myffi.waf_fini(waf)
        --return false;
      end

      log(INFO,"waf_init_mz_mapping_default ok!")


      --#define WAF_MATCH_DATA_ALLOC_KEY(data, dlen) waf_match_data_alloc(data, dlen, 0, 0, 1)
      --#define WAF_MATCH_DATA_ALLOC_VALUE(data, dlen) waf_match_data_alloc(data, dlen, 0, 1, 1)
      local function wafDataConvert(str,type)
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



      local md_method=wafDataConvert("GET","value")
      local md_uri=wafDataConvert("asdfasdfasfddasfasdfasdfasdfasdfasdfasfdasdfasdfadadfasasfdasdfasfdasdfasdf123456789==112233==1234567890asdfdsafsafdasdfasdfsda","value")
      local md_args=wafDataConvert("key1=value1&key2=value2&key3=1%20=%201%20OR%201","value")
      local md_cookies=wafDataConvert("aa=QGluaV9zZXQoImRpc3BsYXlfZXJyb3JzIiwiMCIpO0","value")
      local md_body=wafDataConvert("{'title':'test','age':'12'}","value")
      local md_request_uri=wafDataConvert("/etc/passwd/?key1=value1&key2=value2","value")
      local md_user_agent=wafDataConvert("md_user_agent12233","value")
      local md_referer=wafDataConvert("referer11111","value")
      local md_url=wafDataConvert("http://www.jd.com/etc/passwd/?key1=value1&key2=value2","value")
      local waf_data=myffi.waf_data_create_default(
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
        --fprintf(stderr, "waf_data_create_default error!\n");
        myffi.waf_fini(waf)
        return -1;
      end


      log(INFO,"waf_data_create_default ok!\n")


      -- add headers

      local key=wafDataConvert("Content-Type","key")

      if key == ngx.NULL or key==nil then
        log(INFO,"content_type_key\n")
        myffi.waf_data_destroy(waf_data);
        myffi.waf_fini(waf);
      end



      local value=wafDataConvert("application/x-www-form-urlencoded","value")
      if value == ngx.NULL or value==nil then
        log(INFO,"content_type_value\n")
        myffi.waf_data_destroy(waf_data);
        myffi.waf_fini(waf);
      end






      if myffi.waf_data_add_param(waf_data,PARAM_HDR_TYPE,key,value)==WAF_MATCH_ERR then
        log(INFO,"waf_data_add_param\n")
        myffi.waf_data_destroy(waf_data);
        myffi.waf_fini(waf);
      end
      log(INFO,"waf_data_add_param ok!\n")


      -- match waf data


      if myffi.waf_match(waf,ngx.null,waf_data,WAF_PHASE_REQ_HEADER)==WAF_MATCH_ERR then
        log(INFO,"waf_match \n")
        myffi.waf_data_destroy(waf_data);
        myffi.waf_fini(waf);

      end
      log(INFO,"waf_match ok!\n")


      -- check hit
      local mr
      mr=myffi.waf_match_result_get(waf_data)
      if mr==nil then
        log(INFO,"not hit policy\n")
      else
        log(INFO,"sa_cursor:"..mr.sa_cursor .." policy_cursor:"..mr.policy_cursor.."\n")
      end

      --check sa hit
      if mr.sa_cursor>0 then
        log(INFO,"hit SA\n")
        local s
        for i=0,mr.sa_cursor-1 do
          s=mr.sa_results[i]
          if s~=nil and s~=ngx.null then
            log(INFO,"fingerprint:"..s.fingerprint.." mz:"..s.mz.." action:"..s.action.."\n")
          end
        end
      else
        log(INFO,"not hit SA\n")

      end




      --check policy hit

      if mr.policy_hit_cursor>0 then
        local p
        for i=0,mr.policy_hit_cursor-1 do
          p=mr.policy_hit_results[i]
          if p~=ngx.null and p~=nil and  p.match_state==WAF_MATCHED then

            log(INFO,"hit policyid:"..p.policy_id.." action:"..p.policy_id.."\n")
            local ru
            for j=0,p.cursor-1 do
              ru=p.results[j]
              --local payload_str=ffi.cast("char *",ru.payload)

              local payload_str=ffi.string(ru.payload)

              --log(INFO,"hit rule:"..ru.rule_id.." payload:"..ru.rule_id.." payload_len:"..ru.rule_id.."\n")
              log(INFO,"hit rule:"..ru.rule_id.." payload:"..payload_str.." payload_len:"..ru.payload_len.."\n")
              end
          end
        end
      end

      if waf_data then
        myffi.waf_data_destroy(waf_data)
      end
      log(INFO,"waf_match_data_free ok!\n")
      myffi.waf_fini(waf)
      log(INFO,"waf_fini ok!\n")

      end,
