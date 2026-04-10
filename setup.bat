@echo off
setlocal enabledelayedexpansion

echo ==========================================
echo    CoolCMD One-Key Installer
echo ==========================================

:: 1. Install Tools
echo [*] Installing tools (Clink, Coreutils, LSD, Bat, Ripgrep)...
winget install chrisant996.clink --source winget
winget install uutils.coreutils --source winget
winget install lsd-rs.lsd --source winget
winget install sharkdp.bat --source winget
winget install BurntSushi.ripgrep.MSVC --source winget

echo [*] Installing Oh-My-Posh...
winget install JanDeDobbeleer.OhMyPosh --source winget

echo [*] Installing Meslo Nerd Font (icon support)...
winget install MSFonts.MesloLGM-NF --source winget

echo [OK] All tools and fonts installed.

:: 2. Prepare Clink configuration directory
set "CLINK_CONFIG_DIR=%LOCALAPPDATA%\clink"
if not exist "!CLINK_CONFIG_DIR!" mkdir "!CLINK_CONFIG_DIR!"

:: 3. Deploy Lua scripts and LS_COLORS
echo [*] Deploying configuration files...

set "BASE_URL=https://raw.githubusercontent.com"

echo [*] Fetching configuration files from the cloud...
curl -fsSL "%BASE_URL%/trapd00r/LS_COLORS/refs/heads/master/LS_COLORS" -o "!CLINK_CONFIG_DIR!\LS_COLORS"
if exist "!CLINK_CONFIG_DIR!\LS_COLORS" (
    echo [OK] LS_COLORS synchronized.
)
del /Q "!CLINK_CONFIG_DIR!\LS_COLORS_FULL_CACHE" 2>nul

curl -fsSL "%BASE_URL%/cool-code/coolcmd/refs/heads/master/coolcmd.lua" -o "!CLINK_CONFIG_DIR!\coolcmd.lua"
if exist "!CLINK_CONFIG_DIR!\coolcmd.lua" (
    echo [OK] coolcmd.lua synchronized.
)

:: 4. Set up Clink autorun
echo [*] Setting up Clink autorun...

set "CLINK_INSTALLED=0"

if exist "%ProgramFiles(x86)%\clink\clink.bat" (
    call "%ProgramFiles(x86)%\clink\clink.bat" autorun install -- -q 2>nul
    set "CLINK_INSTALLED=1"
)

if "!CLINK_INSTALLED!"=="0" if exist "%ProgramFiles%\clink\clink.bat" (
    call "%ProgramFiles%\clink\clink.bat" autorun install -- -q 2>nul
    set "CLINK_INSTALLED=1"
)

if "!CLINK_INSTALLED!"=="0" (
    call clink autorun install -- -q 2>nul
)

echo ==========================================
echo    Installation successful!
echo    [Note] Please manually select the "MesloLGM NF" font in Windows Terminal settings,
echo    otherwise icons may appear garbled.
echo ==========================================
pause

echo [*] Cleaning up...
start "" /b cmd /c del "%~f0"&exit