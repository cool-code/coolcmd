@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo    Cool CMD 极客环境「全家桶」一键安装
echo ==========================================

@echo off

:: 1. 使用 winget 安装所有工具和字体
echo [*] 正在安装核心工具 (Clink, Coreutils, LSD, Bat, Ripgrep)...
winget install chrisant996.clink --source winget
winget install uutils.coreutils --source winget
winget install lsd-rs.lsd --source winget
winget install sharkdp.bat --source winget
winget install BurntSushi.ripgrep.MSVC --source winget

echo [*] 正在安装 Oh-My-Posh...
winget install JanDeDobbeleer.OhMyPosh --source winget

echo [*] 正在安装 Meslo Nerd Font (图标支持)...
winget install MSFonts.MesloLGM-NF --source winget

echo [OK] 所有工具与字体安装请求已发出。

:: 2. 准备 Clink 配置目录
set "CLINK_CONFIG_DIR=%LOCALAPPDATA%\clink"
if not exist "!CLINK_CONFIG_DIR!" mkdir "!CLINK_CONFIG_DIR!"

:: 3. 部署 Lua 脚本和 LS_COLORS
echo [*] 正在部署配置文件...

set "BASE_URL=https://raw.githubusercontent.com"

echo [*] 正在从云端拉取配置文件...
curl -fsSL "%BASE_URL%/trapd00r/LS_COLORS/refs/heads/master/LS_COLORS" -o "!CLINK_CONFIG_DIR!\LS_COLORS"
if exist "!CLINK_CONFIG_DIR!\LS_COLORS" (
    echo [OK] LS_COLORS 已同步。
)
del /Q "!CLINK_CONFIG_DIR!\LS_COLORS_FULL_CACHE" 2>nul

curl -fsSL "%BASE_URL%/cool-code/coolcmd/refs/heads/master/coolcmd.lua" -o "!CLINK_CONFIG_DIR!\coolcmd.lua"
if exist "!CLINK_CONFIG_DIR!\coolcmd.lua" (
    echo [OK] coolcmd.lua 已同步。
)

:: 4. 设置 Clink 自动注入
echo [*] 正在设置 Clink 自动运行...
clink autorun install -- -q 

echo ==========================================
echo    安装成功！
echo    【注意】请在 Windows Terminal 设置中手动选择：
echo    「MesloLGM NF」字体，否则图标会显示乱码。
echo ==========================================
pause