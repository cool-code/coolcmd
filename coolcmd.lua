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

-- 以下是一些常用 Linux 命令的 Windows 映射，前提是用户已经安装了对应的工具（如 lsd、rg、bat、procs、btop 等）
local function command_exists(cmd)
    local f = io.popen("where " .. cmd .. " 2>nul")
    if f then
        local res = f:read("*a")
        f:close()
        return res ~= nil and res:match("%S") ~= nil
    end
    return false
end

lsdexists = command_exists("lsd")
lsexists = command_exists("ls")

-- 核心文件查看命令，优先使用 lsd，如果没有则退回到 ls，最后退回到原生 dir
local lsd_base = 'lsd --color auto --icon always --group-directories-first'
local ls_base = 'ls --color=auto --group-directories-first'
local dir_base = 'dir /OG'

if lsdexists then
    os.setalias('l',   lsd_base .. ' $*')
    os.setalias('ls',  lsd_base .. ' $*') 
    os.setalias('ll',  lsd_base .. ' -lh $*') -- 正确显示 Windows 大小单位（KB, MB, GB）
    os.setalias('la',  lsd_base .. ' -A $*')
    os.setalias('lla', lsd_base .. ' -lhA $*')
    os.setalias('l1',  lsd_base .. ' -1 $*')
    os.setalias('l1a', lsd_base .. ' -1A $*')
    os.setalias('lt',  lsd_base .. ' --tree $*')
elseif lsexists then
    os.setalias('l',   ls_base .. ' $*')
    os.setalias('ls',  ls_base .. ' $*')
    os.setalias('ll',  ls_base .. ' -lh $*') -- ls 的 -h 选项在 Windows 上也能正确显示大小单位
    os.setalias('la',  ls_base .. ' -A $*')
    os.setalias('lla', ls_base .. ' -lhA $*')
    os.setalias('l1',  ls_base .. ' -1 $*')
    os.setalias('l1a', ls_base .. ' -1A $*')
    os.setalias('lt',  'tree /F $*')
else
    -- 最后退回到原生 dir，尽量模仿 Unix 风格的输出
    os.setalias('l',   dir_base .. ' /D $*')
    os.setalias('ls',  dir_base .. ' /D $*')
    os.setalias('ll',  dir_base .. ' /Q $*')
    os.setalias('la',  dir_base .. ' /D /A $*')
    os.setalias('lla', dir_base .. ' /Q /A $*')
    os.setalias('l1',  dir_base .. ' /B $*')
    os.setalias('l1a', dir_base .. ' /B /A $*')
    os.setalias('lt',  'tree /F $*')
end

local function set_smart_ld_alias(name, ls_args, dir_args)
    if lsdexists or lsexists then
        local base = (lsdexists and lsd_base or ls_base) .. " " .. ls_args
        -- 逻辑：
        -- 1. A 承接原始参数
        -- 2. 如果 A 为空，补 */
        -- 3. 如果不为空，根据末尾字元 L \ L2 \ L3 进行修补
        -- 4. 统一执行 base %A%
        os.setalias(name, [[@echo off $T set "A=$*" $T ]]..
            [[set "L=%A:~-1%" $T set "L2=%A:~-2%" $T set "L3=%A:~-3%" $T ]]..
            [[if not defined A ( set "A=*/" ) ]]..
            [[else if not "%L3%"=="/*/" if not "%L3%"=="\*/" if not "%L3%"=="\*\" if not "%L3%"=="*\" if not "%L3%"=="*/" if "%L2%"=="*" ( set "A=%A%/" ) ]]..
            [[else if "%L2%"=="/*" ( set "A=%A%/" ) ]]..
            [[else if "%L2%"=="\*" ( set "A=%A%/" ) ]]..
            [[else if not "%L2%"=="*/" if not "%L2%"=="*\" if not "%L%"=="*" if "%L%"=="/" ( set "A=%A%*/" ) ]]..
            [[else if "%L%"=="\" ( set "A=%A%*/" ) ]]..
            [[else ( set "A=%A%/*/" ) $T ]]..
            base..[[ %A% $T set "A=" $T set "L=" $T set "L2=" $T set "L3=" $T echo on]])            
    else
        -- dir 模式重构：统一处理 A 后执行
        os.setalias(name, [[@echo off $T set "A=$*" $T if not defined A (set "A= ") else (]]..
            [[set "E=%A:~-2%" $T if "%E%"=="*\" set "A=%A:~0,-1%") $T ]]..
            dir_base.." "..dir_args..[[ %A% $T set "A=" $T set "E=" $T echo on]])
    end
end

-- ld 系列，显示目录但不显示文件
set_smart_ld_alias('ld',   '-d', '/D /A:D-H-S')
set_smart_ld_alias('lld',  '-ld', '/Q /A:D-H-S')
set_smart_ld_alias('lad',  '-ad', '/D /A:D')
set_smart_ld_alias('llad', '-lad', '/Q /A:D')
set_smart_ld_alias('l1d',  '-1d', '/B /A:D-H-S')
set_smart_ld_alias('l1ad', '-1ad', '/B /A:D')

-- lf 系列，显示文件但不显示目录
-- 只 dir 实现，因为 ls 和 lsd 都没有直接的选项来过滤掉目录
-- 如果依赖 grep，反而会更慢（尤其是大目录），不如直接用 dir 的过滤功能
os.setalias('lf',   dir_base .. ' /D /A:-D-H-S $*')
os.setalias('llf',  dir_base .. ' /Q /A:-D-H-S $*')
os.setalias('laf',  dir_base .. ' /D /A:-D $*')     -- 只看文件（包含隐藏）
os.setalias('llaf', dir_base .. ' /Q /A:-D $*')
os.setalias('l1f',  dir_base .. ' /B /A:-D-H-S $*')
os.setalias('l1af', dir_base .. ' /B /A:-D $*')

-- 安全删除与移动 (uutils coreutils)
-- -i 会在操作前请求确认，-v 会显示过程
if command_exists("rm") then
    os.setalias('rm', 'rm -iv $*')
else
    os.setalias('rm', 'del /p $*')
end

if command_exists("mv") then
    os.setalias('mv', 'mv -iv $*')
else
    os.setalias('mv', 'move $*')
end

if command_exists("cp") then
    os.setalias('cp', 'cp -iv $*')
else
    os.setalias('cp', 'copy $*')
end

-- 增强搜索与查看
if command_exists("rg") then
    os.setalias('grep', 'rg $*')
elseif command_exists("grep") then
    os.setalias('grep', 'grep --color=auto $*')
else 
    os.setalias('grep', 'findstr /R $*')
end

if command_exists("bat") then
    os.setalias('cat', 'bat --paging=never --style=plain $*')
elseif not command_exists("cat") then
    os.setalias('cat', 'type $*')
end

-- 进程管理
if command_exists("btop") then
    os.setalias('top', 'btop $*')
elseif command_exists("btop4win") then
    os.setalias('btop', 'btop4win $*')
    os.setalias('top', 'btop4win $*')
elseif command_exists("htop") then
    os.setalias('top', 'htop $*')
else
    os.setalias('top', 'resmon $*')
end

procsexists = command_exists("procs")
if command_exists("procs") then
    os.setalias('ps', 'procs --color always --paper disable $*')  -- 进程列表查看器
else
    os.setalias('ps', 'tasklist /v $*')
end

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

os.setalias('free', 'powershell -NoLogo -NoProfile -command "Get-WmiObject Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory"')

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