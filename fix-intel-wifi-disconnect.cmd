@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Intel Wi-Fi first-connect disconnect fix

set "SVC=Intel Connectivity Network Service"

rem Require administrator rights; relaunch elevated if needed.
rem fltmc only succeeds as admin and, unlike "net session", does not depend on the Server service.
fltmc >nul 2>&1
if not errorlevel 1 goto menu
if /i "%~1"=="/elevated" goto no_admin
echo Requesting administrator rights...
set "SELF=%~f0"
powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -ArgumentList '/elevated' -Verb RunAs"
if errorlevel 1 goto no_admin
exit /b 0

:no_admin
echo.
echo [ERROR] Administrator rights are required.
echo         Right-click the file and choose "Run as administrator".
echo.
pause
exit /b 1

:menu
cls
echo ==============================================================
echo   Intel Wi-Fi first-connect disconnect fix
echo   Service: %SVC%
echo ==============================================================
echo.
echo   1. Check status
echo   2. Apply fix  (stop and disable the service)
echo   3. Undo fix   (re-enable and start the service)
echo   4. Exit
echo.
choice /c 1234 /n /m "Choose an option [1-4]: "
set "OPT=%errorlevel%"
if "%OPT%"=="1" goto status
if "%OPT%"=="2" goto apply
if "%OPT%"=="3" goto undo
if "%OPT%"=="4" goto end
goto menu

rem ---------------------------------------------------------------
:status
echo.
call :check_installed
if errorlevel 1 goto done
echo [OK] "%SVC%" is installed.
call :show_service
echo.
echo Counting WLAN-AutoConfig event 4003 in the System log, last 30 days...
powershell -NoProfile -Command "$e = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WLAN-AutoConfig'; Id=4003; StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue); Write-Host ('  Event 4003 count : ' + $e.Count); if ($e.Count -gt 0) { Write-Host '  Most recent      :'; $e | Select-Object -First 5 | ForEach-Object { Write-Host ('    ' + $_.TimeCreated) } }"
echo.
echo If the service is Running and you see 4003 events at the times your
echo Wi-Fi dropped, this fix most likely applies to you. Use option 2.
goto done

rem ---------------------------------------------------------------
:apply
echo.
call :check_installed
if errorlevel 1 goto done

echo Stopping "%SVC%"...
sc stop "%SVC%" >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="1062" (
    echo [OK] The service was already stopped.
    goto apply_disable
)
if not "%RC%"=="0" (
    echo [WARN] sc stop failed with exit code %RC%.
    echo        The service will still be disabled. Restart your PC afterwards.
    goto apply_disable
)
powershell -NoProfile -Command "try { (Get-Service -Name $env:SVC).WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20)); exit 0 } catch { exit 1 }"
if errorlevel 1 (
    echo [WARN] The service did not stop within 20 seconds.
    echo        It will still be disabled. Restart your PC afterwards.
) else (
    echo [OK] Service stopped.
)

:apply_disable
echo Disabling "%SVC%"...
sc config "%SVC%" start= disabled >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    echo [FAIL] sc config failed with exit code %RC%. The fix was NOT applied.
    goto done
)
echo [OK] Startup type set to Disabled.
echo.
echo New status:
call :show_service
echo.
echo Fix applied. Disconnect and reconnect to your Wi-Fi network to test.
goto done

rem ---------------------------------------------------------------
:undo
echo.
call :check_installed
if errorlevel 1 goto done

echo Setting "%SVC%" startup type to Automatic...
sc config "%SVC%" start= auto >nul 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" (
    echo [FAIL] sc config failed with exit code %RC%. The undo was NOT applied.
    goto done
)
echo [OK] Startup type set to Automatic.

echo Starting "%SVC%"...
sc start "%SVC%" >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" (
    echo [OK] Service start requested.
) else if "%RC%"=="1056" (
    echo [OK] The service was already running.
) else (
    echo [FAIL] sc start failed with exit code %RC%.
    echo        It is set to Automatic and should start after a restart.
)
echo.
echo New status:
call :show_service
goto done

rem ---------------------------------------------------------------
:check_installed
sc query "%SVC%" >nul 2>&1
set "RC=%errorlevel%"
if "%RC%"=="0" exit /b 0
if "%RC%"=="1060" (
    echo [INFO] "%SVC%" was not found.
    echo        This service is not installed on your PC, so this fix does not apply.
    exit /b 1
)
echo [FAIL] Could not query the service, sc exit code %RC%.
exit /b 1

:show_service
powershell -NoProfile -Command "$s = Get-Service -Name $env:SVC; Write-Host ('  Service status   : ' + $s.Status); Write-Host ('  Startup type     : ' + $s.StartType)"
exit /b 0

:done
echo.
pause
goto menu

:end
endlocal
exit /b 0
