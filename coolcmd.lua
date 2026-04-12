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

-- free: 显示内存使用情况，这个是彩色增强版。
local free_cmd = 'powershell -NoLogo -NoProfile -command "' ..
    -- 1. 基础变量
    '$v_rs=\'\27[0m\'; ' ..
    '$v_u_list=\' B;KB;MB;GB;TB;PB;EB\'.Split(\';\'); ' ..
    '$v_c_list=\'196;208;220;40;39;33;135\'.Split(\';\') | ForEach-Object { \'\27[38;5;\'+$_+\'m\' }; ' ..
    -- 2. 核心格式化函数 (返回 12 位宽度的带颜色字串)
    '$v_f = { param($v_val, $v_col); ' ..
    'if($v_val -le 0){ return (\'\27[38;5;242m0\' + (\' \' * 11) + $v_rs) }; ' ..
    '$v_idx=0; $v_num=[double]$v_val; ' ..
    'while($v_num -ge 1024 -and $v_idx -lt 6){ $v_num /= 1024; $v_idx++ }; ' ..
    '$v_dn=\'{0:N2}\' -f $v_num; $v_un=$v_u_list[$v_idx]; $v_uc=$v_c_list[$v_idx]; ' ..
    '$v_txt=$v_dn + \' \' + $v_un; $v_pad=\' \' * (12 - $v_txt.Length); ' ..
    'if($v_pad.Length -lt 0){$v_pad=\'\'}; ' ..
    'return ($v_col + $v_dn + \' \' + $v_uc + $v_un + $v_rs + $v_pad) ' ..
    '}; ' ..
    -- 3. 获取数据
    '$v_os=Get-CimInstance Win32_OperatingSystem; $v_mem=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory; $v_pg=Get-CimInstance Win32_PageFileUsage; ' ..
    '$v_tm=[double]$v_os.TotalVisibleMemorySize*1024; $v_fm=[double]$v_os.FreePhysicalMemory*1024; ' ..
    '$v_std=[double]($v_mem.StandbyCacheNormalPriorityBytes + $v_mem.StandbyCacheReserveBytes + $v_mem.StandbyCacheCoreBytes); ' ..
    '$v_ca=[double]$v_mem.CacheBytes + $v_std; $v_av=$v_fm + $v_std; $v_sh=[double]$v_mem.WriteCacheMessagesPerSec * 1024; $v_us=$v_tm - $v_av; ' ..
    '$v_stt=([double]($v_pg | Measure-Object -Property AllocatedBaseSize -Sum).Sum) * 1024 * 1024; ' ..
    '$v_stu=([double]($v_pg | Measure-Object -Property CurrentUsage -Sum).Sum) * 1024 * 1024; ' ..
    '$v_ctt=[double]$v_os.TotalVirtualMemorySize * 1024; $v_ctu=$v_ctt - ([double]$v_os.FreeVirtualMemory * 1024); ' ..
    -- 4. 建立彩虹表头颜色 (首列红色 196)
    '$v_h1=\'\27[38;5;196mType       \'; $v_h2=\'\27[38;5;208mtotal        \'; $v_h3=\'\27[38;5;220mused         \'; $v_h4=\'\27[38;5;40mfree         \'; $v_h5=\'\27[38;5;39mshared       \'; $v_h6=\'\27[38;5;33mbuff/cache   \'; $v_h7=\'\27[38;5;135mavailable\' + $v_rs; ' ..
    'write-host ($v_h1 + $v_h2 + $v_h3 + $v_h4 + $v_h5 + $v_h6 + $v_h7); ' ..
    -- 5. 输出横线 (避开 * 运算符引发的报错)
    'write-host (\'\27[38;5;242m---------- ------------ ------------ ------------ ------------ ------------ ------------\' + $v_rs); ' ..
    -- 6. 输出彩色行 (首列红色)
    '$v_s3=\'\27[38;5;242m---         \' + $v_rs; $v_sp=\' \'; $v_lbl=\'\27[38;5;196m\'; ' ..
    'write-host ($v_lbl+\'Mem:       \') -NoNewline; write-host (&$v_f $v_tm (\'\27[38;5;208m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_us (\'\27[38;5;220m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_fm (\'\27[38;5;40m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_sh (\'\27[38;5;39m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_ca (\'\27[38;5;33m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_av (\'\27[38;5;135m\')); ' ..
    'write-host ($v_lbl+\'Swap:      \') -NoNewline; write-host (&$v_f $v_stt (\'\27[38;5;208m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_stu (\'\27[38;5;220m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f ($v_stt-$v_stu) (\'\27[38;5;40m\')) -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3 -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3 -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3; ' ..
    'write-host ($v_lbl+\'Commit:    \') -NoNewline; write-host (&$v_f $v_ctt (\'\27[38;5;208m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f $v_ctu (\'\27[38;5;220m\')) -NoNewline; write-host $v_sp -NoNewline; write-host (&$v_f ($v_ctt-$v_ctu) (\'\27[38;5;40m\')) -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3 -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3 -NoNewline; write-host $v_sp -NoNewline; write-host $v_s3;"'

os.setalias('free', free_cmd)

-- uptime: 显示系统已运行时间及开机时间
os.setalias('uptime',
    'powershell -NoLogo -NoProfile -Command "$o=Get-CimInstance Win32_OperatingSystem; ' ..
    '$s=$o.LastBootUpTime; $u=(Get-Date)-$s; ' ..
    'write-host \'Up time:    \' -NoNewline; \'{0} days, {1} hours, {2} minutes\' -f $u.Days, $u.Hours, $u.Minutes; ' ..
    'write-host \'Boot time:  \' $s"'
)

-- df: 显示磁盘空间使用情况，这个是彩色增强版。
local df_cmd = 'powershell -NoLogo -NoProfile -command "' ..
    -- 1. 初始化环境
    '$v_rs=\'\27[0m\'; ' ..
    '$v_u_list=\'B;KB;MB;GB;TB;PB;EB\'.Split(\';\'); ' ..
    '$v_c_list=\'196;208;220;40;39;33;135\'.Split(\';\') | ForEach-Object { \'\27[38;5;\'+$_+\'m\' }; ' ..
    -- 2. 格式化函数
    '$v_ff = { param($v_val, $v_col); ' ..
    'if($v_val -le 0){ return (\'\27[38;5;242m0           \' + $v_rs) }; ' ..
    '$v_idx=0; $v_num=[double]$v_val; ' ..
    'while($v_num -ge 1024 -and $v_idx -lt 6){ $v_num /= 1024; $v_idx++ }; ' ..
    '$v_dn=\'{0:N2}\' -f $v_num; $v_un=$v_u_list[$v_idx]; $v_uc=$v_c_list[$v_idx]; ' ..
    '$v_txt=$v_dn + \' \' + $v_un; $v_pad=\' \' * (10 - $v_txt.Length); ' ..
    'if($v_pad.Length -lt 0){$v_pad=\'\'}; ' ..
    'return ($v_rs + $v_pad + $v_col + $v_dn + \' \' + $v_uc + $v_un) ' ..
    '}; ' ..
    -- 3. 获取数据
    '$v_vl = Get-Volume; $v_sp=\' \'; $v_lbl=\'\27[38;5;196m\'; ' ..
    -- 4. 输出彩虹表头
    '$v_h1=\'\27[38;5;196mMounted \'; $v_h2=\'\27[38;5;208m   total   \'; $v_h3=\'\27[38;5;220m   used    \'; $v_h4=\'\27[38;5;40m   avail   \'; $v_h5=\'\27[38;5;39mUse% \'; $v_h6=\'\27[38;5;33mFilesystem\' + $v_rs; ' ..
    'write-host ($v_h1 + $v_h2 + $v_h3 + $v_h4 + $v_h5 + $v_h6); ' ..
    -- 5. 分割线
    'write-host (\'\27[38;5;242m------- ---------- ---------- ---------- ---- ----------\' + $v_rs); ' ..
    -- 6. 主循环
    'Get-PSDrive -PSProvider FileSystem | ForEach-Object { ' ..
    '$c=$_; $v_vo=$v_vl | Where-Object { $_.DriveLetter -eq $c.Name }; ' ..
    'if($v_vo){ $v_nm=if($v_vo.FileSystemLabel){$v_vo.FileSystemLabel}else{\'Volume\'}; $v_fs=$v_vo.FileSystem; $v_fsc=\'\27[38;5;135m\' } ' ..
    'else { $v_rt=if($c.DisplayRoot){$c.DisplayRoot.ToLower()}else{\'\'}; $v_nm=if($v_rt){$c.DisplayRoot}else{\'Remote\'}; ' ..
    '$v_fs=if($v_rt -like \'\\\\*\'){\'SMB\'}elseif($v_rt -like \'http*\'){\'WebDAV\'}else{\'Net\'}; $v_fsc=\'\27[38;5;208m\' }; ' ..
    '$v_tt=$c.Used+$c.Free; $v_up=if($v_tt -gt 0){$c.Used/$v_tt}else{0}; ' ..
    '$v_uc=if($v_up -gt 0.9){\'\27[38;5;196m\'}elseif($v_up -gt 0.7){\'\27[38;5;214m\'}else{\'\27[38;5;40m\'}; ' ..
    '$v_pct=([math]::Round($v_up*100)).ToString().PadLeft(3) + \'%\'; ' ..
    -- 物理补齐首列空格
    '$v_mt=$c.Name + [char]58; $v_mp=\' \' * (6 - $v_mt.Length); ' ..
    'write-host ($v_rs + $v_sp + $v_lbl + $v_mt + $v_rs + $v_mp + $v_sp) -NoNewline; ' ..
    'write-host (&$v_ff $v_tt (\'\27[38;5;208m\')) -NoNewline; write-host $v_sp -NoNewline; ' ..
    'write-host (&$v_ff $c.Used (\'\27[38;5;220m\')) -NoNewline; write-host $v_sp -NoNewline; ' ..
    'write-host (&$v_ff $c.Free (\'\27[38;5;40m\')) -NoNewline; write-host $v_sp -NoNewline; ' ..
    'write-host ($v_uc + $v_pct + $v_rs + $v_sp) -NoNewline; ' ..
    -- 卷标与路径上色 (蓝色 33) + 协议上色 (紫色 135)
    'write-host (\'\27[38;5;33m\' + $v_nm + $v_rs + [char]32 + [char]40 + $v_fsc + $v_fs + $v_rs + [char]41); ' ..
    '} | Sort-Object Mounted;"'

os.setalias('df', df_cmd)


-- du: 统计目录或文件磁盘空间使用情况，这个是彩色增强版。
-- Windows 没有直接等价的工具，使用 PowerShell 获取目录大小信息并格式化输出
local du_cmd = 'powershell -NoLogo -NoProfile -Command "' ..
    -- 1. 彩虹单位颜色映射函数
    '$v_f_unit={param($v_n,$v_base_clr); ' ..
    'if([math]::Round($v_n) -eq 0){ $v_s=\'0\'.PadRight(12); return \'\27[38;5;242m\'+$v_s+\'\27[0m\' }; ' ..
    '$v_u=@(\'B\',\'KB\',\'MB\',\'GB\',\'TB\',\'PB\',\'EB\'); ' ..
    '$v_uc=@(\'\27[38;5;196m\',\'\27[38;5;208m\',\'\27[38;5;220m\',\'\27[38;5;40m\',\'\27[38;5;39m\',\'\27[38;5;33m\',\'\27[38;5;135m\'); ' ..
    '$v_x=0; while($v_n -ge 1024 -and $v_x -lt 6){$v_n/=1024; $v_x++}; ' ..
    '$v_num=\'{0:N2}\' -f $v_n; $v_unit=\' {0}\' -f $v_u[$v_x]; ' ..
    '$v_pad=\' \' * (12 - $v_num.Length - $v_unit.Length); ' ..
    'return $v_base_clr + $v_num + \'\27[0m\' + $v_uc[$v_x] + $v_unit + \'\27[0m\' + $v_pad; ' ..
    '}; ' ..
    -- 2. 智慧语义截断函数 (保留后缀版，避开 $true/$false)
    '$v_ft={param($v_s,$v_m,$v_is_d); ' ..
    '$v_enc=[System.Text.Encoding]::GetEncoding(0); ' ..
    'if($v_enc.GetByteCount($v_s) -le $v_m){return $v_s}; ' ..
    'if($v_is_d -eq 1){ ' .. -- 使用 1 代替 $true
    '$v_res=\'\'; $v_cur=0; foreach($v_ch in $v_s.ToCharArray()){$v_st=if([int]$v_ch -gt 255){2}else{1}; if($v_cur+$v_st+3 -gt $v_m){return $v_res+\'...\'}; $v_res+=$v_ch; $v_cur+=$v_st}; return $v_res; ' ..
    '} else { ' ..           -- 档案采取 "主文件名...扩展名" 策略
    '$v_ext=[System.IO.Path]::GetExtension($v_s); $v_base=[System.IO.Path]::GetFileNameWithoutExtension($v_s); ' ..
    '$v_eLen=$v_enc.GetByteCount($v_ext); $v_bMax=$v_m - $v_eLen - 3; if($v_bMax -lt 3){$v_bMax=3}; ' ..
    '$v_res=\'\'; $v_cur=0; foreach($v_ch in $v_base.ToCharArray()){$v_st=if([int]$v_ch -gt 255){2}else{1}; if($v_cur+$v_st -gt $v_bMax){return $v_res+\'...\'+$v_ext}; $v_res+=$v_ch; $v_cur+=$v_st}; return $v_res+$v_ext; ' ..
    '} ' ..
    '}; ' ..
    -- 3. LS_COLORS & 图标渲染
    '$v_lc=@{}; $env:LS_COLORS -split \':\' | ForEach-Object { $v_kv=$_.Split(\'=\'); if($v_kv.Length -eq 2){ $v_lc[$v_kv]=\'\27[\' + $v_kv + \'m\' } }; ' ..
    '$v_fc={param($v_cn,$v_is_d); $v_rst=\'\27[0m\'; if($v_is_d -eq 1){ $v_clr=if($v_lc[\'di\']){$v_lc[\'di\']}else{\'\27[38;5;33m\'}; return $v_clr+\' \'+$v_cn+$v_rst }; ' ..
    '$v_ex=[System.IO.Path]::GetExtension($v_cn).ToLower(); $v_clr=if($v_lc[\'*\'+$v_ex]){$v_lc[\'*\'+$v_ex]}else{\'\27[38;5;250m\'}; ' ..
    'if($v_ex -match \'.exe|.bat|.cmd\'){ return \'\27[38;5;40m \'+$v_cn+$v_rst } ' ..
    'elseif($v_ex -match \'.zip|.7z|.rar|.tar|.gz\'){ return \'\27[38;5;208m \'+$v_cn+$v_rst } ' ..
    'elseif($v_ex -match \'.jpg|.png|.webp|.gif|.ico\'){ return \'\27[38;5;135m \'+$v_cn+$v_rst } ' ..
    'elseif($v_ex -match \'.mp4|.mkv|.avi|.mp3|.wav\'){ return \'\27[38;5;161m \'+$v_cn+$v_rst } ' ..
    'elseif($v_ex -match \'.txt|.md|.pdf|.doc\'){ return \'\27[38;5;253m \'+$v_cn+$v_rst } ' ..
    'else { return $v_clr+\' \'+$v_cn+$v_rst }}; ' ..
    -- 4. 侦测与主循环
    '$v_rp=(Get-Item .).Root.Name; $v_z=(Get-CimInstance Win32_Volume -Filter \\"Name=\'$v_rp\'\\" 2>$null).BlockSize; if(!$v_z){$v_z=4096}; ' ..
    '$v_sS=0; $v_sA=0; $v_cl=\' \' * 10; ' ..
    'write-host (\'\27[38;5;220mSize         \27[38;5;39mAllocated    \27[38;5;253mName\27[0m\'); ' ..
    'write-host (\'\27[38;5;242m------------ ------------ --------------------\27[0m\'); ' ..
    'Get-ChildItem -Path \'.\\$*\' 2>$null | ForEach-Object { ' ..
    '$v_it=$_; if($v_it.PSIsContainer){ ' ..
    '$v_cS=0; $v_cA=0; $v_ct=0; ' ..
    'Get-ChildItem $v_it.FullName -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { ' ..
    '$v_l=$_.Length; $v_cS+=$v_l; $v_cA+=[math]::Ceiling($v_l/$v_z)*$v_z; ' ..
    '$v_ct++; if($v_ct % 500 -eq 0){ ' ..
    '$v_curW=[Console]::WindowWidth; if(!$v_curW){$v_curW=80}; $v_curM=$v_curW - 55; ' ..
    '$v_sn=(&$v_ft $v_it.Name $v_curM 1); ' .. -- 使用 1 代替 $true
    '[Console]::CursorLeft = 0; $v_clr=\' \' * ($v_curW - 1); write-host $v_clr -NoNewline; [Console]::CursorLeft = 0; ' ..
    'write-host (\'{0} {1} {2} \27[38;5;242m[scan...]\27[0m\' -f (&$v_f_unit $v_cS \'\27[38;5;214m\'), (&$v_f_unit $v_cA \'\27[38;5;39m\'), (&$v_fc $v_sn 1)) -NoNewline; ' ..
    '} ' ..
    '}; ' ..
    '[Console]::CursorLeft = 0; $v_clr=\' \' * ([Console]::WindowWidth - 1); write-host $v_clr -NoNewline; [Console]::CursorLeft = 0; ' ..
    '$v_sn=(&$v_ft $v_it.Name ([Console]::WindowWidth - 50) 1); ' .. -- 使用 1 代替 $true
    'write-host (\'{0} {1} {2}/\' -f (&$v_f_unit $v_cS \'\27[38;5;214m\'), (&$v_f_unit $v_cA \'\27[38;5;39m\'), (&$v_fc $v_sn 1)); ' ..
    '} else { ' ..
    '$v_sn=(&$v_ft $v_it.Name ([Console]::WindowWidth - 50) 0); ' .. -- 使用 0 代替 $false
    '$v_cS=$v_it.Length; $v_cA=[math]::Ceiling($v_it.Length/$v_z)*$v_z; ' ..
    'write-host (\'{0} {1} {2}\' -f (&$v_f_unit $v_cS \'\27[38;5;214m\'), (&$v_f_unit $v_cA \'\27[38;5;39m\'), (&$v_fc $v_sn 0)); ' ..
    '}; ' ..
    '$v_sS+=$v_cS; $v_sA+=$v_cA; ' ..
    '}; ' ..
    'write-host (\'\27[38;5;242m\' + (\'-\' * 45) + \'\27[0m\'); ' ..
    'write-host (\'Total Size:      \' + (&$v_f_unit $v_sS \'\27[38;5;214m\')); ' ..
    'write-host (\'Total Allocated: \' + (&$v_f_unit $v_sA \'\27[38;5;39m\')); ' ..
    'write-host (\'\27[38;5;242m(Based on \' + ($v_z/1KB) + \'KB cluster size)\27[0m\')"'

os.setalias('du', du_cmd)

if not command_exists("which") then
    os.setalias('which', 'where $*') -- 查找可执行文件位置
end

os.setalias('clear', 'cls')     -- 清屏
os.setalias('unset', 'set $*=') -- 取消环境变量设置

-- 支持 .. ... .... ... 最多到 16 级的 cd 返回
for i = 2, 16 do
    local dots = string.rep(".", i)
    local path = "cd " .. string.rep("../", i - 1)
    os.setalias(dots, path)
end

os.setalias('cool', '"' .. CLINK_EXE .. '" set >nul && echo clink reloaded.')

-- ==================== Oh My Posh 初始化 ========================
local omp_cache = clink_path .. "omp_cache.lua"
-- 如果缓存不存在，则生成它（你可以手动删除它来更新主题）
if not os.isfile(omp_cache) then
    os.execute('oh-my-posh init cmd --config jandedobbeleer > "' .. omp_cache .. '"')
end
dofile(omp_cache)
-- ==============================================================
