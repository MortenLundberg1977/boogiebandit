@echo off
setlocal
REM Usage: build.bat [pull [branch]] [run^|send^|nosend^|reu^|sendreu]
REM   pull          get the latest version of the current branch from GitHub first
REM   pull branch   switch to that branch and get its latest version
REM   run           start the game in VICE after building
REM   (always)      if a Kung Fu Flash is plugged in over USB, the game is sent to
REM                 it and started on the real C64 (the C64 must show the Kung Fu
REM                 Flash menu); nothing happens if none is found
REM   send          the same, but a missing cartridge or a failed send is an error
REM   nosend        do not send (builds for testing in VICE)
REM   reu, sendreu  like the default / send, but send the REU edition
REM                 (build\boogie-reu.prg: the newspaper and other extras when the
REM                 Kung Fu Flash has its REU on; without an REU it plays as the standard one)
REM Both editions are built every time and both are on the disk image:
REM LOAD"BOOGIE",8 (standard) and LOAD"BOOGIE REU",8.
REM Examples: build.bat run / build.bat pull run / build.bat pull / build.bat nosend
REM For sending: EF3USB_EXE = path of ef3usb.exe (default ..\tools\ef3utils\ef3usb.exe),
REM           KFF_PORT = the cartridge's COM port, e.g. COM3 (found automatically if not set).

REM Remember this script's path now: shift also moves %0.
set "SELF=%~f0"
if /I not "%~1"=="pull" goto pull_done
shift
where git >nul 2>nul
if errorlevel 1 (
    echo git not found. Install Git for Windows or put git.exe on PATH.
    exit /b 1
)
git fetch origin
if errorlevel 1 exit /b 1
set "PULL_BRANCH="
if not "%~1"=="" if /I not "%~1"=="run" if /I not "%~1"=="send" if /I not "%~1"=="nosend" if /I not "%~1"=="reu" if /I not "%~1"=="sendreu" set "PULL_BRANCH=%~1"
if defined PULL_BRANCH shift
REM git may replace this file, so update and restart the script on one line.
if defined PULL_BRANCH (git checkout "%PULL_BRANCH%" && git pull --ff-only && "%SELF%" %1) else (git pull --ff-only && "%SELF%" %1)
echo Could not update from GitHub. Commit or stash your local changes first.
exit /b 1
:pull_done

cd /d "%~dp0"
REM Set KICKASS_JAR to the full path of KickAss.jar if it is not in the parent folder.
if not defined KICKASS_JAR if exist "..\KickAss.jar" set "KICKASS_JAR=..\KickAss.jar"
if not defined KICKASS_JAR set "KICKASS_JAR=KickAss.jar"
if not exist "%KICKASS_JAR%" (
    echo KickAss.jar not found. Set KICKASS_JAR to its full path.
    exit /b 1
)
if not exist build mkdir build
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\java.exe" set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
if not defined JAVA_EXE set "JAVA_EXE=java"

"%JAVA_EXE%" -jar "%KICKASS_JAR%" boogie.asm -odir build -symbolfile > build\kickass.log 2>&1
set "KA_ERROR=%errorlevel%"
type build\kickass.log
if not "%KA_ERROR%"=="0" exit /b 1
REM KickAssembler reports failed .assert checks but still succeeds.
findstr /c:"FAILED" build\kickass.log >nul && (echo A check failed, see above. & exit /b 1)

REM The REU edition: the same source with REU defined.
"%JAVA_EXE%" -jar "%KICKASS_JAR%" boogie.asm -odir build -define REU -o build\boogie-reu.prg > build\kickass-reu.log 2>&1
if errorlevel 1 (type build\kickass-reu.log & echo The REU edition did not build. & exit /b 1)
findstr /c:"FAILED" build\kickass-reu.log >nul && (type build\kickass-reu.log & echo A check failed in the REU edition. & exit /b 1)
findstr /c:"REU extras:" build\kickass-reu.log

if not defined C1541_EXE set "C1541_EXE=c1541"
where "%C1541_EXE%" >nul 2>nul
if errorlevel 1 (
    echo c1541.exe not found, skipping the disk image. Set C1541_EXE to its full path.
    goto disk_done
)
REM Disk filenames must be lowercase: c1541 stores uppercase ASCII as shifted
REM PETSCII, which a LOAD"..." typed on the C64 never matches.
if exist build\boogiebandit.d64 del build\boogiebandit.d64
"%C1541_EXE%" -format "boogie bandit,77" d64 build\boogiebandit.d64 -write build\boogie.prg boogie -write build\boogie-reu.prg "boogie reu" >nul
if errorlevel 1 exit /b 1
:disk_done

REM The same program as a tape image (.t64) for emulators and SD-card loaders.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\make_t64.ps1 build\boogie.prg build\boogiebandit.t64 BOOGIE "BOOGIE BANDIT" >nul
if errorlevel 1 (
    echo Could not write the .t64 tape image.
    exit /b 1
)

echo Built build\boogie.prg, build\boogie-reu.prg, build\boogiebandit.d64 (both) and build\boogiebandit.t64

REM Send it to the Kung Fu Flash too when one is plugged in (always tried,
REM unless nosend; with send a missing cartridge or a failed send is an error).
set "SEND_MODE=auto"
if /I "%~1"=="send" set "SEND_MODE=must"
if /I "%~1"=="nosend" set "SEND_MODE=off"
set "SEND_PRG=build\boogie.prg"
if /I "%~1"=="reu" set "SEND_PRG=build\boogie-reu.prg"
if /I "%~1"=="sendreu" (set "SEND_PRG=build\boogie-reu.prg" & set "SEND_MODE=must")
if "%SEND_MODE%"=="off" goto send_done
if not defined EF3USB_EXE set "EF3USB_EXE=..\tools\ef3utils\ef3usb.exe"
if not exist "%EF3USB_EXE%" (
    echo ef3usb.exe not found at %EF3USB_EXE%, not sending. Set EF3USB_EXE to its full path.
    goto send_fail
)
REM Kung Fu Flash shows up as a USB serial port with vendor 0483, product 5740.
if not defined KFF_PORT for /f "delims=" %%P in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -like 'USB\VID_0483&PID_5740*' -and $_.Name -match '\((COM\d+)\)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1"') do set "KFF_PORT=%%P"
if not defined KFF_PORT (
    echo Kung Fu Flash not found on USB, not sending. Plug it in, or set KFF_PORT, e.g. set KFF_PORT=COM3
    goto send_fail
)
REM The cartridge only takes a program while its menu is on screen (a running
REM game is not stopped): give up after KFF_WAIT seconds (default 20).
if not defined KFF_WAIT set "KFF_WAIT=20"
echo Sending %SEND_PRG% to Kung Fu Flash on %KFF_PORT% (waiting up to %KFF_WAIT% s for its menu)
powershell -NoProfile -Command "$p = Start-Process -FilePath $env:EF3USB_EXE -ArgumentList $env:KFF_PORT,'s',$env:SEND_PRG -NoNewWindow -PassThru; $null = $p.Handle; if (-not $p.WaitForExit([int]$env:KFF_WAIT * 1000)) { $p.Kill(); exit 2 }; exit $p.ExitCode"
if errorlevel 1 (
    echo Not sent. Press the Kung Fu Flash button so the C64 shows its menu, then build again.
    goto send_fail
)
goto send_done
:send_fail
if "%SEND_MODE%"=="must" exit /b 1
:send_done

if /I "%~1"=="run" x64sc -autostart build\boogiebandit.d64
exit /b 0
