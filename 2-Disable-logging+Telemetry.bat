@echo off & cd /d "%~dp0"
fsutil dirty query %systemdrive% >nul && goto:GA || echo Run as Administrator & pause && exit /b
:GA
echo.
echo [44m === Remove log paramerters - Nvidia Container service === [0m
setlocal enabledelayedexpansion
set "KEY1=HKLM\SYSTEM\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem"
set "KEY2=HKLM\SYSTEM\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem\Parameters\LocalSystem\Watchdog\Session"

echo [33m --- ImagePath --- [0m
for /f "tokens=2,*" %%A in ('reg query "%KEY1%" /v ImagePath 2^>nul ^| find /i "ImagePath"') do set "ImagePath=%%B"
if defined ImagePath (
  set "NewImagePath=!ImagePath:-f %%ProgramData%%\NVIDIA\NVDisplay.ContainerLocalSystem.log=!"
  if not "!NewImagePath!"=="!ImagePath!" (
    reg add "%KEY1%" /v ImagePath /t REG_SZ /d "!NewImagePath!" /f >nul
    echo Updated ImagePath
  ) else (
    echo ImagePath already clean
  )
) else (
  echo ImagePath not found
)

echo [33m --- FailureCommand --- [0m
for /f "tokens=2,*" %%A in ('reg query "%KEY1%" /v FailureCommand 2^>nul ^| find /i "FailureCommand"') do set "FailureCommand=%%B"
if defined FailureCommand (
  set "NewFailureCommand=!FailureCommand:%%ProgramData%%\NVIDIA\NvContainerRecoveryNVDisplay.ContainerLocalSystem.log=!"
  if not "!NewFailureCommand!"=="!FailureCommand!" (
    reg add "%KEY1%" /v FailureCommand /t REG_SZ /d "!NewFailureCommand!" /f >nul
    echo Updated FailureCommand
  ) else (
    echo FailureCommand already clean
  )
) else (
  echo FailureCommand not found
)

echo [33m --- Parameters --- [0m
for /f "tokens=2,*" %%A in ('reg query "%KEY2%" /v Parameters 2^>nul ^| find /i "Parameters"') do set "Parameters=%%B"
if defined Parameters (
  set "NewParameters=!Parameters:-f %%ProgramData%%\NVIDIA\DisplaySessionContainer%%d.log=!"
  if not "!NewParameters!"=="!Parameters!" (
    reg add "%KEY2%" /v Parameters /t REG_SZ /d "!NewParameters!" /f >nul
    echo Updated Parameters
  ) else (
    echo Parameters already clean
  )
) else (
  echo Parameters not found
)
endlocal

echo.
echo [44m auto disable other logs  [0m
echo.
reg add "HKLM\SYSTEM\ControlSet001\Services\NVDisplay.ContainerLocalSystem\LocalSystem\NvcDispCorePlugin" /v "DisableLoad" /t REG_DWORD /d "1" /f
reg delete "HKLM\SYSTEM\ControlSet001\Services\NVDisplay.ContainerLocalSystem\LocalSystem\NvcDispCorePlugin" /v "LogFile" /f
reg add "HKLM\SYSTEM\ControlSet001\Services\NVDisplay.ContainerLocalSystem\LocalSystem\NvcDispCorePlugin" /v "LogLevel" /t REG_DWORD /d "0" /f
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\NVDisplay.ContainerLocalSystem\LocalSystem\Watchdog" /v "LogFile" /f
:: NvidiaAIO (https://github.com/cabywabybaby/NvidiaAIO/tree/main):
Reg.exe add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm" /v "LogWarningEntries" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm" /v "LogPagingEntries" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm" /v "LogEventEntries" /t REG_DWORD /d "0" /f
Reg.exe add "HKLM\SYSTEM\ControlSet001\Services\nvlddmkm" /v "LogErrorEntries" /t REG_DWORD /d "0" /f
echo.

echo [44m tweak by zusier + privacy.sxy - Start [0m
echo [33m Opt out of nvidia telemtry  [0m
reg add "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" /v "OptInOrOutPreference" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID44231" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID64640" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID66610" /t REG_DWORD /d "0" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" /v "SendTelemetryData" /t REG_DWORD /d 0 /f
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "NvBackend" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\NvTelemetryContainer" /v "Start" /t REG_DWORD /d "4" /f
echo.
echo [33m uninstall Nvidia telemetry packages [0m
if exist "%ProgramFiles%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL" (
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetryContainer
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetry
)
echo.
echo [33m remove leftover files [0m
del /s %systemdrive%\System32\DriverStore\FileRepository\NvTelemetry*.dll
del %ProgramFiles%\NVIDIA Corporation\NvTelemetry" 2
del %ProgramFiles(x86)%\NVIDIA Corporation\NvTelemetry" 2

echo [33m --- Disable Nvidia Telemetry Container service[0m
PowerShell -ExecutionPolicy Unrestricted -Command "$serviceName = 'NvTelemetryContainer'; Write-Host "^""Disabling service: `"^""$serviceName`"^""."^""; <# -- 1. Skip if service does not exist #>; $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue; if(!$service) {; Write-Host "^""Service `"^""$serviceName`"^"" could not be not found, no need to disable it."^""; Exit 0; }; <# -- 2. Stop if running #>; if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {; Write-Host "^""`"^""$serviceName`"^"" is running, stopping it."^""; try {; Stop-Service -Name "^""$serviceName"^"" -Force -ErrorAction Stop; Write-Host "^""Stopped `"^""$serviceName`"^"" successfully."^""; } catch {; Write-Warning "^""Could not stop `"^""$serviceName`"^"", it will be stopped after reboot: $_"^""; }; } else {; Write-Host "^""`"^""$serviceName`"^"" is not running, no need to stop."^""; }; <# -- 3. Skip if already disabled #>; $startupType = $service.StartType <# Does not work before .NET 4.6.1 #>; if(!$startupType) {; $startupType = (Get-WmiObject -Query "^""Select StartMode From Win32_Service Where Name='$serviceName'"^"" -ErrorAction Ignore).StartMode; if(!$startupType) {; $startupType = (Get-WmiObject -Class Win32_Service -Property StartMode -Filter "^""Name='$serviceName'"^"" -ErrorAction Ignore).StartMode; }; }; if($startupType -eq 'Disabled') {; Write-Host "^""$serviceName is already disabled, no further action is needed"^""; }; <# -- 4. Disable service #>; try {; Set-Service -Name "^""$serviceName"^"" -StartupType Disabled -Confirm:$false -ErrorAction Stop; Write-Host "^""Disabled `"^""$serviceName`"^"" successfully."^""; } catch {; Write-Error "^""Could not disable `"^""$serviceName`"^"": $_"^""; }"
echo [44m tweak by zusier + privacy.sxy - End [0m
echo.


echo [44m --- Delete NVIDIA residual telemetry files[0m
del /s %SystemRoot%\System32\DriverStore\FileRepository\NvTelemetry*.dll
rmdir /s /q "%ProgramFiles(x86)%\NVIDIA Corporation\NvTelemetry"
rmdir /s /q "%ProgramFiles%\NVIDIA Corporation\NvTelemetry"
for /f "delims=" %%a in ('where /r C:\ *NvTelemetry*') do (if exist "%%a" (del /f /q /s "%%a"))
for %%a in ("C:\Program Files\NVIDIA Corporation\Display.NvContainer\plugins\LocalSystem\DisplayDriverRAS", "C:\Program Files\NVIDIA Corporation\DisplayDriverRAS", "C:\ProgramData\NVIDIA Corporation\DisplayDriverRAS") do (if exist %%a (rd /s /q %%a))
:: delete the two files below from the C:\Windows
del /F /Q "C:\Windows\NvContainerRecovery.bat"
del /F /Q "C:\Windows\NvTelemetryContainerRecovery.bat"

set "baseDir=C:\\Windows\\System32\\DriverStore\\FileRepository"
for /D %%d in ("%baseDir%\\nv_*") do (
   if exist "%%~fd\\Display.NvContainer\\NvContainerRecovery.bat" (
       del /Q "%%~fd\\Display.NvContainer\\NvContainerRecovery.bat"
   )
)

echo.
pause
exit