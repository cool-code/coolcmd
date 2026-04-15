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

-- ====================== LS_COLORS & LS_ICONS CONFIGURATION =============================
-- 设置 LS_COLORS 和 LS_ICONS 的字符长度上限
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
--      LS_ICONS 的默认值 4096 是基于目前的配置文件内容长度预估的，通常不会超过
--这个长度。
local LS_COLORS_MAX_LENGTH = 16383
local LS_ICONS_MAX_LENGTH = 4096
-- ============================================================================

local function set_ls_env(env_name, max_length, full_str)
    if full_str and full_str ~= "" then
        local final_str = full_str
        -- 动态截断：根据用户当前的配置值进行截断
        if #final_str > max_length then
            local truncated = final_str:sub(1, max_length)
            local last_colon = truncated:match(".*():")
            if last_colon then
                final_str = truncated:sub(1, last_colon - 1)
            end
        end

        final_str = final_str:gsub(":$", "")
        os.setenv(env_name, final_str)
    end
end

-- ============================================================================

local ls_colors_raw_file = clink_path .. "LS_COLORS"
local ls_colors_cache_file = clink_path .. "LS_COLORS_FULL_CACHE" -- 缓存完整解析结果

local function get_ls_colors_data()
    -- 1. 尝试读取完整解析后的缓存
    local f_cache = io.open(ls_colors_cache_file, "r")
    if f_cache then
        local cached_data = f_cache:read("*all")
        f_cache:close()
        if cached_data and cached_data ~= "" then return cached_data end
    end

    -- 2. 如果没有缓存，解析 trapd00r 的原始文件
    local f_raw = io.open(ls_colors_raw_file, "r")
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
    local f_save = io.open(ls_colors_cache_file, "w")
    if f_save then
        f_save:write(full_result)
        f_save:close()
    end

    return full_result
end

-- 4. 执行加载与动态截断

set_ls_env("LS_COLORS", LS_COLORS_MAX_LENGTH, get_ls_colors_data())

-- ============================================================================

local ls_icons_raw_file = clink_path .. "LS_ICONS"
local ls_icons_cache_file = clink_path .. "LS_ICONS_FULL_CACHE" -- 缓存完整解析结果

local function get_ls_icons_data()
    -- 1. 尝试读取完整解析后的缓存
    local f_cache = io.open(ls_icons_cache_file, "r")
    if f_cache then
        local cached_data = f_cache:read("*all")
        f_cache:close()
        if cached_data and cached_data ~= "" then return cached_data end
    end

    -- 2. 如果没有缓存，解析 LS_ICONS 的原始文件
    local f_raw = io.open(ls_icons_raw_file, "r")
    if not f_raw then return nil end

    local entries = {}
    local translate = {
        dir = "di",
        file = "fi",
    }

    for line in f_raw:lines() do
        line = line:gsub("#.*$", "")
        local key, icon = line:match("^%s*(%S+):%s*(%S+)")
        if key and icon then
            if translate[key] then
                table.insert(entries, translate[key] .. "=" .. icon)
            else
                key = "*." .. key
                table.insert(entries, key .. "=" .. icon)
            end
        end
    end
    f_raw:close()

    local full_result = table.concat(entries, ":")

    -- 3. 将最全的解析结果存入缓存
    local f_save = io.open(ls_icons_cache_file, "w")
    if f_save then
        f_save:write(full_result)
        f_save:close()
    end

    return full_result
end

-- 4. 执行加载与动态截断
set_ls_env("LS_ICONS", LS_ICONS_MAX_LENGTH, get_ls_icons_data())

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


-- 初始化 powershell 环境
local ps_command_header = 'powershell -NoLogo -NoProfile -command "' ..
    --重置颜色
    "$crs='\27[0m';" ..
    -- 彩虹色，灰，银，白
    "$cl='196;208;220;40;39;33;135;242;250;253'.Split(';')|%{'\27[38;5;'+$_+'m'};" ..
    -- 定义 Write-Host 的别名 wh，简化后续输出
    "sal wh Write-Host;"

-- 格式化函数
-- 数字转换为带颜色的字符串，单位自动转换为 B/KB/MB/GB/TB/PB/EB，并且根据使用的单位显示对应的颜色。
-- 返回带颜色的 7 位数字 + 空格 + 单位
-- 整体占 10 字符宽度，数字和单位都是右对齐（不足左侧补空格）
-- 如果值为 0 或负数，直接返回 "      0  B"（6 个空格 + 1 个数字 + 2 个空格 + 1 个单位），并使用灰色显示
local ps_format_size = "$ul=' B;KB;MB;GB;TB;PB;EB'.Split(';');" .. -- 单位
    "$v_ff={param($v,$vc);" ..
    "if($v -le 0){" ..
    "return($cl[7]+'      0  B'+$crs)" ..
    "};" ..
    "$i=0;" ..
    "$vn=[double]$v;" ..
    "while($vn -ge 1024 -and $i -lt 6){" ..
    "$vn/=1024;" ..
    "$i++" ..
    "};" ..
    "$n=('{0:N2}' -f $vn).PadLeft(7);" ..
    "$u=$ul[$i];" ..
    "$uc=$cl[$i];" ..
    "return ($vc+$n+' '+$uc+$u+$crs)" ..
    "};"

-- PadCenter 函数：将文本居中并根据指定宽度进行左右补齐
local ps_pad_center = "$v_pcf={param($vt,$vw);" ..
    "if($vt.Length -ge $vw){return $vt};" ..
    "$vp=$vw-$vt.Length;" ..
    "$vpl=[math]::Floor($vp/2);" ..
    "$vpr=[math]::Ceiling($vp/2);" ..
    "return (' '*$vpl)+$vt+(' '*$vpr)" ..
    "};"

-- free: 显示内存使用情况，这个是彩色增强版。
local free_cmd = ps_command_header .. ps_format_size .. ps_pad_center ..
    -- 获取数据
    "$v_os=Get-CimInstance Win32_OperatingSystem;" ..
    "$v_mem=Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory;" ..
    "$v_pg=Get-CimInstance Win32_PageFileUsage;" ..
    "$v_tm=[double]$v_os.TotalVisibleMemorySize*1024;" ..
    "$v_fm=[double]$v_os.FreePhysicalMemory*1024;" ..
    "$v_std=[double]($v_mem.StandbyCacheNormalPriorityBytes+$v_mem.StandbyCacheReserveBytes+$v_mem.StandbyCacheCoreBytes);" ..
    "$v_ca=[double]$v_mem.CacheBytes+$v_std;" ..
    "$v_av=$v_fm+$v_std;" ..
    "$v_sh=[double]$v_mem.WriteCacheMessagesPerSec*1024;" ..
    "$v_us=$v_tm-$v_av;" ..
    "$v_stt=([double]($v_pg|measure -Prop AllocatedBaseSize -Sum).Sum)*1024*1024;" ..
    "$v_stu=([double]($v_pg|measure -Prop CurrentUsage -Sum).Sum)*1024*1024;" ..
    "$v_ctt=[double]$v_os.TotalVirtualMemorySize*1024;" ..
    "$v_ctu=$v_ctt-([double]$v_os.FreeVirtualMemory*1024);" ..
    -- 输出彩虹表头
    "$h1=$cl[0]+'  Type   ';" ..
    "$h2=$cl[1]+'   Total   ';" ..
    "$h3=$cl[2]+'   Used    ';" ..
    "$h4=$cl[3]+'   Free    ';" ..
    "$h5=$cl[4]+'  Shared   ';" ..
    "$h6=$cl[5]+'Buff/Cache ';" ..
    "$h7=$cl[6]+' Available' + $crs;" ..
    "wh ($h1+$h2+$h3+$h4+$h5+$h6+$h7);" ..
    -- 输出横线 (避开 * 运算符引发的报错)
    "wh ($cl[7]+'-------- ---------- ---------- ---------- ---------- ---------- ----------'+$crs);" ..
    -- 输出彩色行
    "wh ($cl[0]+(&$v_pcf 'Mem' 8)+' '+(&$v_ff $v_tm $cl[1])+' '+(&$v_ff $v_us $cl[2])+' '+(&$v_ff $v_fm $cl[3])+' '+(&$v_ff $v_sh $cl[4])+' '+(&$v_ff $v_ca $cl[5])+' '+(&$v_ff $v_av $cl[6]));" ..
    "wh ($cl[0]+(&$v_pcf 'Swap' 8)+' '+(&$v_ff $v_stt $cl[1])+' '+(&$v_ff $v_stu $cl[2])+' '+(&$v_ff ($v_stt-$v_stu) $cl[3]));" ..
    "wh ($cl[0]+(&$v_pcf 'Commit' 8)+' '+(&$v_ff $v_ctt $cl[1])+' '+(&$v_ff $v_ctu $cl[2])+' '+(&$v_ff ($v_ctt-$v_ctu) $cl[3]));" ..
    '"'

os.setalias('free', free_cmd)

-- df: 显示磁盘空间使用情况，这个是彩色增强版。
local df_cmd = ps_command_header .. ps_format_size .. ps_pad_center ..
    -- 输出彩虹表头
    "$h1=$cl[0]+'Drive ';" ..
    "$h2=$cl[1]+'   Size    ';" ..
    "$h3=$cl[2]+'   Used    ';" ..
    "$h4=$cl[3]+'   Avail   ';" ..
    "$h5=$cl[4]+'Use% ';" ..
    "$h6=$cl[5]+'FileSystem ';" ..
    "$h7=$cl[6]+'VolumeName';" ..
    "wh ($h1+$h2+$h3+$h4+$h5+$h6+$h7+$crs);" ..
    -- 分割线
    "wh ($cl[7]+'----- ---------- ---------- ---------- ---- ---------- ----------'+$crs); " ..
    -- 主循环
    "Get-CimInstance Win32_LogicalDisk|Sort-Object Name|%{" ..
    "$c=$_;" ..
    "if($c.DriveType -eq 4){" ..
    "$v_pn=if($c.ProviderName){$c.ProviderName.ToLower()}else{''};" ..
    -- 远程卷显示共享名称和协议类型，协议类型通过 ProviderName 的前缀判断（SMB、WebDAV、FTP、SFTP、SSHFS、NFS）
    "$v_nm=if($c.VolumeName){if($v_pn){$cl[6]+$c.VolumeName+' ('+$c.ProviderName+')'}else{$cl[6]+$c.VolumeName+' ('+$c.Description+')'}}elseif($v_pn){$cl[6]+$c.VolumeSerialNumber+' ('+$c.ProviderName+')'}else{$cl[7]+$c.VolumeSerialNumber+' ('+$c.Description+')'};" ..
    "$v_fs=if($v_pn -like '\\\\*'){'SMB'}elseif($v_pn -like 'http*'){'WebDAV'}elseif($v_pn -like 'ftp*'){'FTP'}elseif($v_pn -like 'sftp*'){'SFTP'}elseif($v_pn -like 'sshfs*'){'SSHFS'}elseif($v_pn -like 'nfs*' -or $v_pn -like '/nfs/*'){'NFS'}else{'Net'};" ..
    -- 根据协议类型显示不同的颜色，Net、SMB、WebDAV、FTP、SFTP、SSHFS、NFS 分别对应 红、橙、黄、绿、青、蓝、紫 七种颜色
    "$v_fsc=if($v_fs -eq 'SMB'){$cl[1]}elseif($v_fs -eq 'WebDAV'){$cl[2]}elseif($v_fs -eq 'FTP'){$cl[3]}elseif($v_fs -eq 'SFTP'){$cl[4]}elseif($v_fs -eq 'SSHFS'){$cl[5]}elseif($v_fs -eq 'NFS'){$cl[6]}else{$cl[0]};" ..
    "}else{" ..
    -- 本地卷显示卷标和文件系统类型
    "$v_nm=if($c.VolumeName){$cl[6]+$c.VolumeName}else{$cl[7]+$c.VolumeSerialNumber+' ('+$c.Description+')'};" ..
    "$v_fst=if($c.FileSystem){$c.FileSystem.ToLower()}else{''};" ..
    "$v_fs=$c.FileSystem;" ..
    -- 根据文件系统类型显示不同的颜色，HPFS‌、CDFS、UDF、NTFS、FAT/FAT32、exFAT、ReFS 分别对应 红、橙、黄、绿、青、蓝、紫 七种颜色，未知文件系统使用灰色
    "$v_fsc=if($v_fst -eq 'hpfs'){$cl[0]}elseif($v_fst -eq 'cdfs'){$cl[1]}elseif($v_fst -eq 'udf'){$cl[2]}elseif($v_fst -like 'ntfs*'){$cl[3]}elseif($v_fst -like 'fat*'){$cl[4]}elseif($v_fst -eq 'exfat'){$cl[5]}elseif($v_fst -eq 'refs'){$cl[6]}else{$v_b};" ..
    "};" ..
    "$v_mt=$c.Size; $v_mu=$c.Size-$c.FreeSpace; $v_mf=$c.FreeSpace;" ..
    "$v_up=if($v_mt -gt 0){$v_mu/$v_mt}else{0};" ..
    -- 使用红色表示使用率大于 90%，使用橙色表示使用率大于 70%，否则使用绿色
    "$v_uc=if($v_up -gt 0.9){$cl[0]}elseif($v_up -gt 0.7){$cl[1]}else{$cl[3]};" ..
    "$v_pct=([math]::Round($v_up*100)).ToString().PadLeft(3) + '%';" ..
    -- 物理补齐首列空格
    "wh ($cl[0]+(&$v_pcf $c.Name 5)+$crs+' ') -NoNewline;" ..
    "wh ((&$v_ff $v_mt $cl[1])+$crs+' ') -NoNewline;" ..
    "wh ((&$v_ff $v_mu $cl[2])+$crs+' ') -NoNewline;" ..
    "wh ((&$v_ff $v_mf $cl[3])+$crs+' ') -NoNewline;" ..
    "wh ($v_uc+$v_pct+$crs+' ') -NoNewline;" ..
    "wh ($v_fsc+(&$v_pcf $v_fs 10)+$crs+' ') -NoNewline;" ..
    "wh ($v_nm+$crs);" ..
    '};"'

os.setalias('df', df_cmd)

-- du: 统计目录或文件磁盘空间使用情况，这个是彩色增强版。
-- Windows 没有直接等价的工具，使用 PowerShell 获取目录大小信息并格式化输出
local du_cmd = ps_command_header .. ps_format_size ..
    -- 智慧语义截断函数 (按视觉宽度截断，中文和 Emoji 友好，支持宽字符，组合表情不被截断，优先保留扩展名，末尾添加省略号)
    "$v_ft={param($v,$m,$d);" ..
    -- 1. 初始化 Unicode 文本元素迭代器（处理组合字元如 Emoji）
    "$it=[Globalization.StringInfo]::GetTextElementEnumerator($v);" ..
    "$a=@();while($it.MoveNext()){" ..
    "$x=$it.GetTextElement();" ..
    -- 处理 ZWJ (0x200D) 连体逻辑：如果当前字元或前一个字元是连字元，则合并到上一个元素
    "if($a.Count -and (([char[]]$a[-1])[-1]-eq 0x200D -or ([char[]]$x)-eq 0x200D)){$a[-1]+=$x}else{$a+=$x}" ..
    "}" ..
    -- 2. 计算视觉宽度数组 $w：CJK/全角/组合字元计为 2，ASCII 计为 1
    "$w=$a|%{$u=1}{if($_-match'[\\u1100-\\u11ff\\u2e80-\\ua4cf\\uac00-\\ud7af\\uf900-\\ufaff\\ufe30-\\ufe4f\\uff00-\\uffee]' -or $_.Length-gt 1){$u=2};$u};" ..
    -- 3. 检查总宽度 $o，若未超标则直接返回原字串
    "$o=0;$w|%{$o+=$_};" ..
    -- 目录模式 (d=1) 的特殊处理：末尾保留一个字符宽度给斜杠，如果超标则截断并在末尾添加斜杠
    "if($d-eq 1){$o+=1}" ..
    "if($o-le $m){if($d-eq 1){$v+='\\'};return $v}" ..
    -- 4. 处理文件模式 (d=0)：保留扩展名
    "if($d-eq 0){" ..
    "$x=[IO.Path]::GetExtension($v);$z=[IO.Path]::GetFileNameWithoutExtension($v);" ..
    -- 如果扩展名比限制还宽，直接整体截断文件名，否则保留扩展名并递归截断主文件名
    "$wl=$m-$x.Length; if($wl-lt 3){return (&$v_ft $v $m 3)}" ..
    -- 递归调用自己来截断主文件名，最后拼回点号和扩展名
    "return (&$v_ft $z $wl 2)+$x" ..
    "}" ..
    -- 5. 执行截断逻辑：从头累加视觉宽度，直到逼近限制 $n
    "$n=$m-2;if($d-eq 1){$n=$m-3}elseif($d-eq 2){$n=$m-1}" ..
    "$r='';$s=0;for($j=0;$j-lt $a.Count;$j++){" ..
    "if($s+$w[$j]-gt $n){break}$r+=$a[$j];$s+=$w[$j]" ..
    "}" ..
    -- 6. 返回截断后的结果，并根据视觉剩余宽度精确补齐省略号（'.'）,文件模式末尾加 '..'，目录模式末尾加 '../'
    "if($d-eq 1){return $r+('.'*($m-$s-1))+'\\'}" ..
    "return $r+('.'*($m-$s))" ..
    "};" ..
    -- LS_COLORS & LS_ICONS 渲染
    "$vlc=@{};$env:LS_COLORS-split':'|%{$k,$v=$_-split'=';if($v){$vlc[$k]='\27['+$v+'m'}};" ..
    "$vli=@{};$env:LS_ICONS-split':'|%{$k,$v=$_-split'=';if($v){$vli[$k]=$v}};" ..
    "$v_fc={param($v_cn,$v_xt,$v_is_d);" ..
    "$vc=$cl[8];$vi=' ';" ..
    "if($v_is_d -eq 1){" ..
    "$vc=if($vlc['di']){$vlc['di']}else{$cl[5]};" ..
    "$vi=if($vli['di']){$vli['di']+' '}else{' '};" ..
    "}else{" ..
    "$vk='*'+$v_xt.ToLower();" ..
    "$vc=if($vlc[$vk]){$vlc[$vk]}elseif($vlc['fi']){$vlc['fi']};" ..
    "$vi=if($vli[$vk]){$vli[$vk]+' '}elseif($vli['fi']){$vli['fi']+' '};" ..
    "};" ..
    "return $vc+$vi+$v_cn+$crs" ..
    "};" ..
    -- 控制台操作函数
    "$C=[Console];" ..
    "$cw={$C::WindowWidth};" ..
    "$v_fcl={" ..
    "$C::CursorLeft=0;" ..
    "wh (' '*((&$cw)-1)) -NoNewline;" ..
    "$C::CursorLeft=0;" ..
    "};" ..
    -- 侦测与主循环
    "$v_rp=(Get-Item .).Root.Name;" ..
    "$v_z=(Get-CimInstance Win32_Volume|?{$_.Name -eq $v_rp}).BlockSize;" ..
    "if(!$v_z){$v_z=4096};" ..
    "$v_sS=0;$v_sA=0;$v_cl=' '*10;" ..
    "wh ($cl[1]+'   Size    '+$cl[3]+' Allocated '+$cl[5]+'   Name'+$crs);" ..
    "wh ($cl[7]+'---------- ---------- -----------------------'+$crs);" ..
    "gci '$*' 2>$null|%{" ..
    "$vit=$_;" ..
    "$v_xt=[IO.Path]::GetExtension($vit.Name);" ..
    "if($vit.PSIsContainer){" ..
    "$v_cS=0;$v_cA=0;$v_ct=0;" ..
    "gci $vit.FullName -r -File -ea 0|%{" ..
    "$v_l=$_.Length;$v_cS+=$v_l;$v_cA+=[math]::Ceiling($v_l/$v_z)*$v_z;" ..
    "$v_ct++;if($v_ct % 500 -eq 0){" ..
    "$v_sn=(&$v_ft $vit.Name ((&$cw)-49) 1);" .. -- 使用 1 代替 $true
    "&$v_fcl;" ..
    "wh ((&$v_ff $v_cS $cl[1])+' '+(&$v_ff $v_cA $cl[3])+' '+(&$v_fc $v_sn $v_xt 1)+' [scan...]') -NoNewline;" ..
    "}" ..
    "};" ..
    "&$v_fcl;" ..
    "$v_sn=(&$v_ft $vit.Name ((&$cw)-40) 1);" .. -- 使用 1 代替 $true
    "wh ((&$v_ff $v_cS $cl[1])+' '+(&$v_ff $v_cA $cl[3])+' '+(&$v_fc $v_sn $v_xt 1));" ..
    "}else{ " ..
    "$v_sn=(&$v_ft $vit.Name ((&$cw)-40) 0);" .. -- 使用 0 代替 $false
    "$v_cS=$vit.Length; $v_cA=[math]::Ceiling($vit.Length/$v_z)*$v_z;" ..
    "wh ((&$v_ff $v_cS $cl[1])+' '+(&$v_ff $v_cA $cl[3])+' '+(&$v_fc $v_sn $v_xt 0));" ..
    "};" ..
    "$v_sS+=$v_cS;$v_sA+=$v_cA;" ..
    "};" ..
    "wh ($cl[7]+('-'*45)+$crs);" ..
    "wh ($cl[1]+'Total Size:      '+(&$v_ff $v_sS $cl[1]));" ..
    "wh ($cl[3]+'Total Allocated: '+(&$v_ff $v_sA $cl[3]));" ..
    "wh ($cl[7]+'(Based on '+($v_z/1KB)+'KB cluster size)'+$crs)" .. '"'

os.setalias('du', du_cmd)

-- uptime: 显示系统已运行时间及开机时间（彩色）
local uptime_cmd = ps_command_header ..
    "$o=Get-CimInstance Win32_OperatingSystem;" ..
    "$s=$o.LastBootUpTime;" ..
    "$u=(Get-Date)-$s;" ..
    "wh ($cl[0]+'Up time:    '+$cl[1]+$u.Days+' days, '+$cl[2]+$u.Hours+' hours, '+$cl[3]+$u.Minutes+' minutes' + $cr);" ..
    "wh ($cl[4]+'Boot time:  '+$cl[5]+$s.ToString('D')+' '+$cl[6]+$s.ToString('T')+$cr)" .. '"'

os.setalias('uptime', uptime_cmd)

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
