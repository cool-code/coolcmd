@echo off
:: CoolCMD Loader - One-Key Setup Script
:: This script automates the installation of Clink and related tools, and sets up the configuration.

setlocal enabledelayedexpansion

echo ==========================================
echo    CoolCMD Loader - One-Key Setup
echo ==========================================

:: 0. Check for Winget
where winget >nul 2>nul
if !errorlevel! neq 0 (
    echo [*] Winget not found. Attempting to install...
    powershell -NoProfile -Nologo -ExecutionPolicy Bypass -Command "irm asheroto.com/winget | iex"
    if !errorlevel! neq 0 (
        echo [Error] Failed to install Winget. Please install it manually.
        exit /b 1
    )
)

:: 1. Install Clink
echo [*] Installing Clink...
winget install chrisant996.clink --source winget

set "CLINK_INSTALLED=0"

for /f "tokens=2*" %%a in ('reg query "HKCU\Software\Clink" /v "InstallDir" 2^>nul') do set "CLINK_BAT=%%b\clink.bat"
if exist "!CLINK_BAT!" (
    set "CLINK_INSTALLED=1"
)

if "!CLINK_INSTALLED!"=="0" if exist "%ProgramFiles(x86)%\clink\clink.bat" (
    set "CLINK_BAT=%ProgramFiles(x86)%\clink\clink.bat"
    set "CLINK_INSTALLED=1"
)

if "!CLINK_INSTALLED!"=="0" if exist "%ProgramFiles%\clink\clink.bat" (
    set "CLINK_BAT=%ProgramFiles%\clink\clink.bat"
    set "CLINK_INSTALLED=1"
)

if "!CLINK_INSTALLED!"=="0" (
    echo [Error] Clink installation not detected. Please ensure Clink is installed and try again.
    exit /b 1
)

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
) else (
    echo [Error] Failed to fetch LS_COLORS. Please check your internet connection and try again.
    exit /b 1
)

:: Clear old cache files
if exist "!CLINK_CONFIG_DIR!\LS_COLORS_FULL_CACHE" del /Q "!CLINK_CONFIG_DIR!\LS_COLORS_FULL_CACHE"
if exist "!CLINK_CONFIG_DIR!\COOL_TOOLS_CACHE.lua" del /Q "!CLINK_CONFIG_DIR!\COOL_TOOLS_CACHE.lua"

curl -fsSL "%BASE_URL%/cool-code/coolcmd/refs/heads/master/coolcmd.lua" -o "!CLINK_CONFIG_DIR!\coolcmd.lua"
if exist "!CLINK_CONFIG_DIR!\coolcmd.lua" (
    :: Set alias for easy reload
    echo= >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo= >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo ------------------------------------------------------------------------------------------ >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo os.setalias^('cool', 'call ^"!CLINK_BAT:\=\\!^" set ^>nul^&echo clink reloaded.'^) >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo ------------------------------------------------------------------------------------------ >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo= >> "!CLINK_CONFIG_DIR!\coolcmd.lua"
    echo [OK] coolcmd.lua synchronized.
) else (
    echo [Error] Failed to fetch coolcmd.lua. Please check your internet connection and try again.
    exit /b 1
)

:: 4. Install additional tools (Coreutils, LSD, Bat, Ripgrep, btop, Procs, Oh-My-Posh) and fonts (Meslo Nerd Font)

echo [*] Installing uutils coreutils...
winget install uutils.coreutils --source winget

echo [*] Installing LSD (Enhanced ls)...
winget install lsd-rs.lsd --source winget

echo [*] Installing Bat (Enhanced Cat)...
winget install sharkdp.bat --source winget

echo [*] Installing Ripgrep (Search Tool)...
winget install BurntSushi.ripgrep.MSVC --source winget

echo [*] Installing btop (System Monitor)...
winget install aristocratos.btop4win --source winget

echo [*] Installing Procs (Enhanced Task Manager)...
winget install dalance.procs --source winget

echo [*] Installing Oh-My-Posh (Prompt Theme Engine)...
winget install JanDeDobbeleer.OhMyPosh --source winget

echo [*] Installing Meslo Nerd Font (icon support)...
oh-my-posh font install meslo

echo [OK] All tools and fonts installed.

:: 5. Set up Clink autorun
echo [*] Setting up Clink autorun...
call "!CLINK_BAT!" autorun install -- -q >nul

echo ==========================================
echo  DONE! Type 'cool' to reload (if needed).
echo ==========================================
echo [Note] Please manually select the "MesloLGM Nerd Font" font in Windows Terminal settings for proper icon display.
echo=
pause

echo [*] Cleaning up...
start "" /b cmd /c del "%~f0"
