-- ================= CONFIGURATION =================
-- 设置 LS_COLORS 的字符长度上限
-- 7000: 最安全，cmd 的 echo %LS_COLORS% 还能勉强工作
-- 8191: CMD 命令行参数的理论极限
-- 32767: Windows 进程环境变量的理论极限（lsd 能读到，但 echo 会崩溃）
-- 用户可以随时修改这个值，重启 CMD 立即生效
local LS_COLORS_MAX_LENGTH = 7000 
-- =================================================

local clink_path = os.getenv("LOCALAPPDATA").."\\clink\\"
local raw_file = clink_path.."LS_COLORS"
local cache_file = clink_path.."LS_COLORS_FULL_CACHE" -- 缓存完整解析结果

local function get_ls_colors_data()
    -- 1. 尝试读取完整解析后的缓存
    local f_cache = io.open(cache_file, "r")
    if f_cache then
        local cached_data = f_cache:read("*all")
        f_cache:close()
        if cached_data and cached_data ~= "" then return cached_data end
    end

    -- 2. 如果没有缓存，解析 trapd00r 的原始文件
    local f_raw = io.open(raw_file, "r")
    if not f_raw then return nil end

    local entries = {}
    local translate = {
        DIR = "di", FILE = "fi", LINK = "ln", EXEC = "ex", SOCK = "so", 
        FIFO = "pi", BLK = "bd", CHR = "cd", ORPHAN = "or", MISSING = "mi", 
        SETUID = "su", SETGID = "sg", CAPABILITY = "ca", STICKY = "st", 
        OTHER_WRITABLE = "ow", STICKY_OTHER_WRITABLE = "tw", 
        MULTIHARDLINK = "mh", NORMAL = "no", DOOR = "do"
    }

    for line in f_raw:lines() do
        line = line:gsub("#.*$", "")
        local key, color = line:match("^%s*(%S+)%s+(%S+)")
        if key and color then
            if not key:match("^TERM") and not key:match("LS_COLORS") and key ~= "*" then
                local final_key = translate[key] or key
                if final_key:match("^%.") then final_key = "*" .. final_key end
                if color:match("%d") or color == "target" then
                    table.insert(entries, final_key .. "=" .. color)
                end
            end
        end
    end
    f_raw:close()

    local full_result = table.concat(entries, ":")

    -- 3. 将最全的解析结果存入缓存
    local f_save = io.open(cache_file, "w")
    if f_save then
        f_save:write(full_result)
        f_save:close()
    end

    return full_result
end

-- 4. 执行加载与动态截断
local full_str = get_ls_colors_data()
if full_str and full_str ~= "" then
    local final_str = full_str
    -- 动态截断：根据用户当前的配置值进行截断
    if #final_str > LS_COLORS_MAX_LENGTH then
        local truncated = final_str:sub(1, LS_COLORS_MAX_LENGTH)
        local last_colon = truncated:match(".*():")
        if last_colon then 
            final_str = truncated:sub(1, last_colon - 1) 
        end
    end
    
    final_str = final_str:gsub(":$", "")
    os.setenv("LS_COLORS", final_str)
end

------------------------------------------------------------------------------------------

-- 核心文件查看 (lsd)
os.setalias('ls', 'lsd --color always --icon always $*')
os.setalias('ll', 'lsd -l --color always --icon always $*')
os.setalias('la', 'lsd -A --color always --icon always $*')
os.setalias('lt', 'lsd --tree --color always --icon always $*')

-- 安全删除与移动 (uutils coreutils)
-- -i 会在操作前请求确认，-v 会显示过程
os.setalias('rm', 'rm -iv $*')
os.setalias('cp', 'cp -iv $*')
os.setalias('mv', 'mv -iv $*')

-- 增强搜索与查看
os.setalias('grep', 'rg $*')
os.setalias('cat', 'bat --paging=never --style=plain $*')

-- 进程管理
os.setalias('ps', 'procs --color always --paper disable $*')  -- 进程列表查看器
os.setalias('top', 'btop $*')  -- 系统资源监视器

-- kill系列，忽略 -9 等 Unix 讯号，强制按 PID 杀进程
-- 内部直接使用 set _P_= 来实现 unset 的功能
os.setalias('kill', '@echo off $T set "_P_=" $T for %A in ($*) do set "_P_=%A" $T if defined _P_ taskkill /f /pid %_P_% $T set "_P_=" $T echo on')

-- killall: 按完整名称杀进程
os.setalias('killall', '@echo off $T set "_N_=" $T for %A in ($*) do set "_N_=%A" $T if defined _N_ taskkill /f /im %_N_% $T set "_N_=" $T echo on')

-- pkill: 按部分名称加通配符杀进程
os.setalias('pkill', '@echo off $T set "_N_=" $T for %A in ($*) do set "_N_=%A" $T if defined _N_ taskkill /f /im %_N_%* $T set "_N_=" $T echo on')

-- 其他常用 Linux 映射
os.setalias('df', 'df -h $*')     -- 以易读的格式显示磁盘空间
os.setalias('du', 'du -h -d1 $*') -- 显示当前目录下各文件夹大小
os.setalias('which', 'where $*') -- 查找可执行文件位置
os.setalias('clear', 'cls')     -- 清屏
os.setalias('unset', 'set $*=') -- 取消环境变量设置

os.setalias('..', 'cd ..')
os.setalias('...', 'cd ../..')
os.setalias('....', 'cd ../../..')
os.setalias('.....', 'cd ../../../..')
os.setalias('......', 'cd ../../../../..')
os.setalias('.......', 'cd ../../../../../..')
os.setalias('........', 'cd ../../../../../../..')

-- Oh My Posh 初始化
local omp_cmd = 'oh-my-posh init cmd --config jandedobbeleer'
local status, handle = pcall(io.popen, omp_cmd)
if status and handle then
    local config = handle:read("*a")
    handle:close()
    if config and config ~= "" then
        assert(load(config))()
    end
end