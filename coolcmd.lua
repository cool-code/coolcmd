-- ============================ CLINK_PATH ====================================

local clink_path = os.getenv("LOCALAPPDATA") .. "\\clink\\"

-- =================== LANGUAGE DETECTION & CACHE =============================
-- Windows 上的语言环境设置比较麻烦，尤其是对于那些依赖 LANG 环境变量来判断输出
-- 编码的工具（如 lsd、rg、bat 等）。这个模块的目的是在第一次运行时侦测系统语言
-- 环境，并将结果缓存到文件中，后续直接加载缓存以避免重复侦测带来的性能问题。
-- 如果需要更改为其他语言环境，可以直接编辑生成的 LANG_ENV.lua 文件，修改其中的
-- LANG 设置即可。
local lang_env_file = clink_path .. "LANG_ENV.lua"

-- 侦测逻辑（只在第一次运行）
if not os.isfile(lang_env_file) then
    local handle = io.popen("powershell -NoProfile -Command \"(Get-Culture).Name\"")
    local res = handle:read("*a")
    handle:close()
    local lang_val = (res and res ~= "") and (res:gsub("%s+", ""):gsub("-", "_") .. ".UTF-8") or "en_US.UTF-8"

    local f_save = io.open(lang_env_file, "w")
    if f_save then
        f_save:write('os.setenv("LANG", "' .. lang_val .. '")\n')
        f_save:close()
        -- 第一次生成后，为了让当前会话生效，执行一次
        os.setenv("LANG", lang_val)
    end
end

-- ====================== LS_COLORS CONFIGURATION =============================
-- 设置 LS_COLORS 的字符长度上限
-- 8191: CMD 命令行参数的理论极限，cmd 的 echo %LS_COLORS% 还能勉强工作。
-- 32767: Windows 进程环境变量的理论极限（lsd 能读到，但 echo 会崩溃）。
-- 用户可以随时修改这个值，重启 CMD 立即生效。
-- 注意：
--      这个值只是一个动态截断点，真正存储在缓存中的 LS_COLORS 值是完整的，用
--      户可以通过修改这个值来调整实际使用的长度。目前设置的 16383 实际上大于
--      LS_COLORS 的缓存长度，目的是为了保证现在和将来默认都尽量不截断，尽量多
--      地保留颜色配置让大部分工具（包括 lsd, rg）能正常工作，同时给其它环境变
--      量留够空间。但缺点是用 echo %LS_COLORS% 来查看时看不到内容。如果用户需
--      要在 echo 或 set 中看到这个环境变量的值，请将它设置为 8191 或更小。
local LS_COLORS_MAX_LENGTH = 16383
-- ============================================================================

local raw_file = clink_path .. "LS_COLORS"
local cache_file = clink_path .. "LS_COLORS_FULL_CACHE" -- 缓存完整解析结果

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
        DIR = "di",
        FILE = "fi",
        LINK = "ln",
        EXEC = "ex",
        SOCK = "so",
        FIFO = "pi",
        BLK = "bd",
        CHR = "cd",
        ORPHAN = "or",
        MISSING = "mi",
        SETUID = "su",
        SETGID = "sg",
        CAPABILITY = "ca",
        STICKY = "st",
        OTHER_WRITABLE = "ow",
        STICKY_OTHER_WRITABLE = "tw",
        MULTIHARDLINK = "mh",
        NORMAL = "no",
        DOOR = "do"
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

-- ====================== TOOL DETECTION WITH CACHE ===========================
local tool_cache_file = clink_path .. "COOL_TOOLS_CACHE.lua"
local _TOOLS = {}

-- 1. 尝试加载缓存
if os.isfile(tool_cache_file) then
    _TOOLS = dofile(tool_cache_file) -- 这会直接填充 _TOOLS 表
else
    -- 2. 缓存不存在，执行一次性批量侦测 (慢速，仅执行一次)
    local tools_to_check = { "lsd", "ls", "bat", "cat", "rg", "grep", "btop", "btop4win", "htop", "procs", "rm", "mv",
        "cp", "df", "du", "which", "free" }
    local check_cmd = "where " .. table.concat(tools_to_check, " ") .. " 2>nul"
    local f = io.popen(check_cmd)
    if f then
        local output = f:read("*a"):lower()
        f:close()

        -- 生成缓存文件内容
        local cache_content = "return {\n"
        for _, tool in ipairs(tools_to_check) do
            local found = output:match("[\\/]" .. tool:lower() .. "%.?e?x?e?%s") or
                output:match("[\\/]" .. tool:lower() .. "$")
            if found then
                cache_content = cache_content .. '    ["' .. tool .. '"] = true,\n'
            end
        end
        cache_content = cache_content .. "}"
        -- 写入文件
        local f_save = io.open(tool_cache_file, "w")
        if f_save then
            f_save:write(cache_content)
            f_save:close()
            _TOOLS = dofile(tool_cache_file)
        end
    end
end

-- 封装查询函数
local function command_exists(cmd)
    return _TOOLS[cmd] == true
end
-- ============================================================================

-- 以下是一些常用 Linux 命令的 Windows 映射。
-- 如果用户已经安装了对应的工具（如 lsd、rg、bat、procs、btop 等），则优先使用
-- 它们来提供更接近 Linux 的使用体验；如果没有安装，则退回到 Windows 原生命令
--（如 dir、tasklist、resmon 等），并尽量调整参数以模仿 Linux 的输出格式。
local lsd_exists = command_exists("lsd")
local ls_exists = command_exists("ls")

-- 文件查看命令，优先使用 lsd，如果没有则退回到 ls，最后退回到原生 dir
local lsd_base = 'lsd --color auto --icon always --group-directories-first'
local ls_base = 'ls --color=auto --group-directories-first'
local dir_base = 'dir /OG'

if lsd_exists or ls_exists then
    local base = (lsd_exists and lsd_base or ls_base)
    -- -h 参数显示人类可读的文件大小，-A 显示隐藏文件，-1 列表显示（每行一个）
    os.setalias('l', base .. ' $*')
    os.setalias('ls', base .. ' $*')
    os.setalias('ll', base .. ' -lh $*')
    os.setalias('la', base .. ' -A $*')
    os.setalias('lla', base .. ' -lhA $*')
    os.setalias('l1', base .. ' -1 $*')
    os.setalias('l1a', base .. ' -1A $*')
else
    -- 最后退回到原生 dir，尽量模仿 Unix 风格的输出
    os.setalias('l', dir_base .. ' /D $*')
    os.setalias('ls', dir_base .. ' /D $*')
    os.setalias('ll', dir_base .. ' /Q $*')
    os.setalias('la', dir_base .. ' /D /A $*')
    os.setalias('lla', dir_base .. ' /Q /A $*')
    os.setalias('l1', dir_base .. ' /B $*')
    os.setalias('l1a', dir_base .. ' /B /A $*')
end

if lsd_exists then
    os.setalias('lt', lsd_base .. ' --tree $*')
else
    os.setalias('lt', 'tree /F $*')
end

-- ld 系列命令的目标是只显示目录，不显示文件。
-- ls 和 lsd 都没有直接的选项来实现这个功能。
-- 解决方案是创建一个智能别名，先处理用户输入的路径参数，动态地在末尾添加通配符
-- 和过滤选项，然后再调用 ls/lsd 或 dir 来执行。这个智能别名会根据用户输入路径
-- 参数自动调整，确保无论用户输入什么样的路径，都能正确地只显示目录。
local function set_smart_ld_alias(name, ls_args, dir_args)
    if lsd_exists or ls_exists then
        local base = (lsd_exists and lsd_base or ls_base) .. " " .. ls_args
        -- 逻辑：
        -- 1. A 承接原始参数
        -- 2. 如果 A 为空，补 */
        -- 3. 如果不为空，根据末尾字元 L \ L2 \ L3 进行修补
        -- 4. 统一执行 base %A%
        os.setalias(name, [[@echo off $T set "A=$*" $T ]] ..
            [[set "L=%A:~-1%" $T set "L2=%A:~-2%" $T set "L3=%A:~-3%" $T ]] ..
            [[if not defined A (set "A=*/") ]] ..
            [[else if not "%L3%"=="/*/" ]] ..
            [[if not "%L3%"=="\*/" ]] ..
            [[if not "%L3%"=="\*\" ]] ..
            [[if not "%L3%"=="*\" ]] ..
            [[if not "%L3%"=="*/" ]] ..
            [[if "%L2%"=="*" (set "A=%A%/") ]] ..
            [[else if "%L2%"=="/*" (set "A=%A%/") ]] ..
            [[else if "%L2%"=="\*" (set "A=%A%/") ]] ..
            [[else if not "%L2%"=="*/" ]] ..
            [[if not "%L2%"=="*\" ]] ..
            [[if not "%L%"=="*" ]] ..
            [[if "%L%"=="/" (set "A=%A%*/") ]] ..
            [[else if "%L%"=="\" (set "A=%A%*/") ]] ..
            [[else (set "A=%A%/*/") $T ]] ..
            base .. [[ %A% $T ]] ..
            [[set "A=" $T set "L=" $T set "L2=" $T set "L3=" $T echo on]])
    else
        local base = dir_base .. " " .. dir_args
        -- dir 模式重构：统一处理 A 后执行
        os.setalias(name, [[@echo off $T set "A=$*" $T set "E=%A:~-2%" $T ]] ..
            [[if not defined A (set "A= ") ]] ..
            [[else if "%E%"=="*\" (set "A=%A:~0,-1%") $T ]] ..
            base .. [[ %A% $T ]] ..
            [[set "A=" $T set "E=" $T echo on]])
    end
end

set_smart_ld_alias('ld', '-d', '/D /A:D-H-S')
set_smart_ld_alias('lld', '-ld', '/Q /A:D-H-S')
set_smart_ld_alias('lad', '-ad', '/D /A:D')
set_smart_ld_alias('llad', '-lad', '/Q /A:D')
set_smart_ld_alias('l1d', '-1d', '/B /A:D-H-S')
set_smart_ld_alias('l1ad', '-1ad', '/B /A:D')

-- lf 系列命令的目标跟 ld 正相反，只显示文件，但不显示目录。
-- 暂时只用 dir 实现，因为 ls 和 lsd 都没有直接的选项来只显示文件。
-- 如果依赖 grep，也只能实现 llf, llaf, l1f, l1af。
-- lf 和 laf 这种非文件单列的用 grep 无法正确过滤。
os.setalias('lf', dir_base .. ' /D /A:-D-H-S $*')
os.setalias('llf', dir_base .. ' /Q /A:-D-H-S $*')
os.setalias('laf', dir_base .. ' /D /A:-D $*')
os.setalias('llaf', dir_base .. ' /Q /A:-D $*')
os.setalias('l1f', dir_base .. ' /B /A:-D-H-S $*')
os.setalias('l1af', dir_base .. ' /B /A:-D $*')

-- rm, mv, cp: 安全删除、移动和复制 (uutils coreutils)
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

-- grep: 增强搜索与查看
if command_exists("rg") then
    os.setalias('grep', 'rg $*')
elseif command_exists("grep") then
    os.setalias('grep', 'grep --color=auto $*')
else
    os.setalias('grep', 'findstr /R $*')
end

-- cat: 文件查看器
if command_exists("bat") then
    os.setalias('cat', 'bat --paging=never --style=plain $*')
elseif not command_exists("cat") then
    os.setalias('cat', 'type $*')
end

-- top: 进程管理
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

-- ps: 进程列表查看器
if command_exists("procs") then
    os.setalias('ps', 'procs --color always --paper disable $*')
else
    os.setalias('ps', 'tasklist /v $*')
end

-- kill系列，忽略 -9 等 Unix 讯号，强制按 PID 杀进程
os.setalias('kill',
    '@echo off $T set "_P_=" $T for %A in ($*) do set "_P_=%A" $T if defined _P_ taskkill /f /pid %_P_% $T set "_P_=" $T echo on')

-- killall: 按完整名称杀进程
os.setalias('killall',
    '@echo off $T set "_N_=" $T for %A in ($*) do set "_N_=%A" $T if defined _N_ taskkill /f /im %_N_% $T set "_N_=" $T echo on')

-- pkill: 按部分名称加通配符杀进程
os.setalias('pkill',
    '@echo off $T set "_N_=" $T for %A in ($*) do set "_N_=%A" $T if defined _N_ taskkill /f /im %_N_%* $T set "_N_=" $T echo on')

-- free: 显示内存使用情况
if command_exists("free") then
    os.setalias('free', 'free -h $*')
else
    -- Windows 没有直接等价的工具，使用 PowerShell 获取内存使用情况并格式化输出
    local free_cmd = 'powershell -NoLogo -NoProfile -Command "' ..
        '$z=Get-CimInstance Win32_OperatingSystem; ' ..
        '$m=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; ' ..
        '$pf=Get-CimInstance Win32_PageFileUsage; ' ..
        -- 数据换算 (KB -> GB)
        '$u_tot=$z.TotalVisibleMemorySize/1mb; ' ..
        '$u_fre=$z.FreePhysicalMemory/1mb; ' ..
        '$u_cac=($m.CacheBytes+$m.StandbyCacheNormalPriorityBytes+$m.StandbyCacheReserveBytes+$m.StandbyCacheCoreBytes)/1gb; ' ..
        '$u_av=$u_fre+($m.StandbyCacheNormalPriorityBytes+$m.StandbyCacheReserveBytes+$m.StandbyCacheCoreBytes)/1gb; ' ..
        '$u_sh=$m.WriteCacheMessagesPerSec/1mb; ' ..
        '$u_usd=$u_tot-$u_av; ' ..
        -- Swap 与 Commit
        '$s_tot=$pf.AllocatedBaseSize/1kb; ' ..
        '$s_usd=$pf.CurrentUsage/1kb; ' ..
        '$s_fre=$s_tot-$s_usd; ' ..
        '$c_tot=$z.TotalVirtualMemorySize/1mb; ' ..
        '$c_usd=($z.TotalVirtualMemorySize-$z.FreeVirtualMemory)/1mb; ' ..
        -- 构建输出
        '$r=@(); ' ..
        '$f=\'{0:N2}GB\'; ' ..
        '$r+=New-Object PSObject -Property @{Type=\'Mem:\';   total=$f -f $u_tot; used=$f -f $u_usd; free=$f -f $u_fre; shared=$f -f $u_sh; \'buff/cache\'=$f -f $u_cac; available=$f -f $u_av}; ' ..
        '$r+=New-Object PSObject -Property @{Type=\'Swap:\';  total=$f -f $s_tot; used=$f -f $s_usd; free=$f -f $s_fre; shared=\'---\'; \'buff/cache\'=\'---\'; available=\'---\'}; ' ..
        '$r+=New-Object PSObject -Property @{Type=\'Commit:\';total=$f -f $c_tot; used=$f -f $c_usd; free=$f -f ($c_tot-$c_usd); shared=\'---\'; \'buff/cache\'=\'---\'; available=\'---\'}; ' ..
        '$r | Select-Object Type,total,used,free,shared,\'buff/cache\',available | Format-Table -AutoSize"'
    os.setalias('free', free_cmd)
end

-- uptime: 显示系统已运行时间及开机时间
os.setalias('uptime',
    'powershell -NoLogo -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; ' ..
    '$s=$o.LastBootUpTime; $u=(Get-Date)-$s; ' ..
    'write-host \'Up time:    \' -NoNewline; \'{0} days, {1} hours, {2} minutes\' -f $u.Days, $u.Hours, $u.Minutes; ' ..
    'write-host \'Boot time:  \' $s"'
)

-- 其他常用 Linux 映射
if command_exists("df") then
    os.setalias('df', 'df -h $*') -- 以易读的格式显示磁盘空间
else
    -- Windows 没有直接等价的工具，使用 PowerShell 获取磁盘空间信息并格式化输出
    os.setalias('df',
        'powershell -NoLogo -NoProfile -command "Get-PSDrive -PSProvider FileSystem | ' ..
        'Select-Object Name, ' ..
        '@{Name=\'Used\';Expression={($_.Used/1GB).ToString(\'0.00\') + \' GB\'}}, ' ..
        '@{Name=\'Free\';Expression={($_.Free/1GB).ToString(\'0.00\') + \' GB\'}}, ' ..
        '@{Name=\'Used%\';Expression={if($_.Used -gt 0){ (\'{0:P2}\' -f ($_.Used / ($_.Used + $_.Free))) } else {\'0.00 %\'}}} | ' ..
        'Format-Table -AutoSize"'
    )
end

if command_exists("du") then
    os.setalias('du', 'du -h -d1 $*') -- 显示当前目录下各文件夹大小
else
    -- Windows 没有直接等价的工具，使用 PowerShell 获取目录大小信息并格式化输出
    os.setalias('du',
        'powershell -NoLogo -NoProfile -Command "Get-ChildItem -Path \'.\\$*\' -Directory | ' ..
        'Select-Object Name, @{Name=\'Size\';Expression={ ' ..
        '$size = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum; ' ..
        'if($size){(\'{0:N2} GB\' -f ($size / 1GB))} else {\'0.00 GB\'} }} | Format-Table -AutoSize"'
    )
end

if not command_exists("which") then
    os.setalias('which', 'where $*') -- 查找可执行文件位置
end

os.setalias('clear', 'cls')     -- 清屏
os.setalias('unset', 'set $*=') -- 取消环境变量设置

os.setalias('..', 'cd ..')
os.setalias('...', 'cd ../..')
os.setalias('....', 'cd ../../..')
os.setalias('.....', 'cd ../../../..')
os.setalias('......', 'cd ../../../../..')
os.setalias('.......', 'cd ../../../../../..')
os.setalias('........', 'cd ../../../../../../..')

os.setalias('cool', '"' .. CLINK_EXE .. '" set >nul && echo clink reloaded.')

-- ==================== Oh My Posh 初始化 ========================
local omp_cache = clink_path .. "omp_cache.lua"
-- 如果缓存不存在，则生成它（你可以手动删除它来更新主题）
if not os.isfile(omp_cache) then
    os.execute('oh-my-posh init cmd --config jandedobbeleer > "' .. omp_cache .. '"')
end
dofile(omp_cache)
-- ==============================================================
