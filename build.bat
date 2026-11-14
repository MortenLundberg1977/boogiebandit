@echo off
setlocal
REM Usage: build.bat [pull [branch]] [run]
REM   pull          get the latest version of the current branch from GitHub first
REM   pull branch   switch to that branch and get its latest version
REM   run           start the game in VICE after building
REM Examples: build.bat run / build.bat pull run

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
if not "%~1"=="" if /I not "%~1"=="run" set "PULL_BRANCH=%~1"
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

if not defined C1541_EXE set "C1541_EXE=c1541"
where "%C1541_EXE%" >nul 2>nul
if errorlevel 1 (
    echo c1541.exe not found, skipping the disk image. Set C1541_EXE to its full path.
    goto disk_done
)
REM Disk filenames must be lowercase: c1541 stores uppercase ASCII as shifted
REM PETSCII, which a LOAD"..." typed on the C64 never matches.
if exist build\boogiebandit.d64 del build\boogiebandit.d64
"%C1541_EXE%" -format "boogie bandit,77" d64 build\boogiebandit.d64 -write build\boogie.prg boogie >nul
if errorlevel 1 exit /b 1
:disk_done

REM The same program as a tape image (.t64) for emulators and SD-card loaders.
powershell -NoProfile -ExecutionPolicy Bypass -File tools\make_t64.ps1 build\boogie.prg build\boogiebandit.t64 BOOGIE "BOOGIE BANDIT" >nul
if errorlevel 1 (
    echo Could not write the .t64 tape image.
    exit /b 1
)

echo Built build\boogie.prg, build\boogiebandit.d64 and build\boogiebandit.t64
if /I "%~1"=="run" x64sc -autostart build\boogiebandit.d64
