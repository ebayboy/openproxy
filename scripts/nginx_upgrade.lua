
function sleep(n)
    os.execute("sleep "..n)
end

function string_split(str, split_char)
    local sub_str_tab = {};
    while (true and str~="" ) do
        local pos = string.find(str, split_char)
        if (not pos) then
            sub_str_tab[#sub_str_tab + 1] = str
            break;
        end
        local sub_str = string.sub(str, 1, pos - 1);
        sub_str_tab[#sub_str_tab + 1] = sub_str
        str = string.sub(str, pos + 1, #str)
    end
    return sub_str_tab;
end

--TOP is common function

function upgrade_success(old_pid)
    os.execute("kill -QUIT "..old_pid)
end

function upgrade_recovery(old_pid, new_pid)
    os.execute("kill -HUP "..old_pid)
    sleep(3)
    os.execute("kill -QUIT "..new_pid)
end

function get_workers()
    local pids_files = io.popen("ps -ef | grep nginx | grep 'nginx: worker process' | grep -v grep | awk '{ print $2}'")
    local worker_pids = pids_files:read("*all")
    local pids = string_split(worker_pids, '\n')
    return pids
end

function get_masters()
    local pids_file = io.popen("ps -ef | grep 'nginx: master process' | grep -v grep | awk '{ print $2 }'")
    local master_pids = pids_file:read("*all")
    local pids = string_split(master_pids, '\n')
    return  pids
end

function nginx_status_check()
    --1. check master number
end

function check_winch_ok(old_workers)
    -- check old_workers exit ok
    local exit_num = 0
    for _, v in ipairs(old_workers) do
        if (v ~= "")  then
            local cmd = "ps -ef | grep 'nginx: worker process' | grep -v grep | grep "..v.." | wc -l"
            local ret = io.popen(cmd)
            local count = ret:read("*all")
            print("cmd:"..cmd)
            print("count:"..count)
            if (tonumber(count) == 0) then
                print("worker: "..v.." exit ok!")
                exit_num = exit_num + 1
            else 
                print("worker: "..v.."not exit!")
            end
        end
    end
    if (exit_num == #old_workers) then
        return 1;
    end

    return 0
end

---MAIN START

nginx_status_check()

local old_master_pid_file = "/usr/local/myresty/nginx/logs/nginx.pid"
file = io.open(old_master_pid_file, "r")
io.input(file)
old_master_pid = io.read()
io.close(file)

old_worker_pids = get_workers()
for _, v in ipairs(old_worker_pids) do
    if (v ~= "") then
        print("old worker:" .. v)
    end
end

-- 1. kill -USR2 
if (old_master_pid) then
    os.execute('kill -USR2 '..old_master_pid)
    sleep(2)
else
    print("not found master pid")
    return
end

local new_master_pids = get_masters()
local new_worker_pids = get_workers()

print("#new_master_pids" .. #new_master_pids)

local new_master_pid = 0
for _,v in ipairs(new_master_pids) do
    if (v ~= "") then
        if (tonumber(v) ~= tonumber(old_master_pid)) then
            new_master_pid = tonumber(v)
            break
        end
    end
end

print("old_master_pid:"..old_master_pid.."  new_master_pid:"..new_master_pid)

new_worker_pids = get_workers()
for _, v in ipairs(new_worker_pids) do
    if (v ~= "") then
        print("new worker:" .. v)
    end
end

--2. kill -WINCH
os.execute("kill -WINCH "..old_master_pid)
sleep(2)

if (check_winch_ok(old_worker_pids)) then
    print("winch check ok!")
else
    print("winch check fail! upgrade_recovery ..")
    upgrade_recovery(old_master_pid, new_master_pid)
    return
end

--3. kill -QUIT
os.execute("kill -QUIT "..old_master_pid)

print("old master quit ok!")





