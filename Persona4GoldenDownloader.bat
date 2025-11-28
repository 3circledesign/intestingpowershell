@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Persona 4 Golden Denuvo Free (All 3 branches) — with delete prompt

REM ===== CONFIG =====
set "OWNER=barryhamsy"
set "REPO=onlinefix"
set "PATH_RAW="  REM leave blank (RARs are at branch root)

REM Per-branch expectations (001–021, 022–043, 044–058)
set "BRANCH1=persona4goldenPart1" & set "EXPECT1=21"
set "BRANCH2=persona4goldenPart2" & set "EXPECT2=22"
set "BRANCH3=persona4goldenPart3" & set "EXPECT3=15"
set /a EXPECT_TOTAL=%EXPECT1%+%EXPECT2%+%EXPECT3%

set "UNRAR=%~dp0UnRAR.exe"
set "WORK=%~dp0"
set "TMP_LIST=%WORK%filelist.tmp"
set "TMP_URLS=%WORK%urls.tmp"

REM ===== PRECHECKS =====
if not exist "%UNRAR%" (
  echo [ERROR] UnRAR.exe not found next to this script.
  pause & exit /b 1
)
where powershell >nul 2>&1 || (echo [ERROR] PowerShell not found on PATH.& pause & exit /b 1)
set "CURL=" & where curl >nul 2>&1 && (set "CURL=curl")

del "%TMP_LIST%" 2>nul & del "%TMP_URLS%" 2>nul
break > "%TMP_LIST%" 2>nul
break > "%TMP_URLS%" 2>nul

REM ===== URL ENCODE PATH (if provided) =====
set "PATH_ENC="
if not "%PATH_RAW%"=="" (
  for /f "usebackq delims=" %%E in (`
    powershell -NoProfile -Command ^
      "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "[System.Web.HttpUtility]::UrlEncode('%PATH_RAW%') -replace '\+','%%20'"
  `) do set "PATH_ENC=%%E"
)

echo ==============================================
echo  Persona 4 Golden Denuvo Free Patch (All 3 branches)
echo ==============================================
echo.

call :COLLECT "%BRANCH1%" %EXPECT1% || goto :hard_fail
call :COLLECT "%BRANCH2%" %EXPECT2% || goto :hard_fail
call :COLLECT "%BRANCH3%" %EXPECT3% || goto :hard_fail

REM ===== VERIFY TOTAL COUNT =====
set /a COUNT_TOTAL=0
for /f "usebackq tokens=1,2 delims=|" %%i in ("%TMP_URLS%") do set /a COUNT_TOTAL+=1

echo [INFO] Total .rar files queued across branches: %COUNT_TOTAL%
if not %COUNT_TOTAL%==%EXPECT_TOTAL% (
  echo [ERROR] Expected %EXPECT_TOTAL% parts total but found %COUNT_TOTAL%.
  pause & goto :end
)

echo.
echo This will download all %EXPECT_TOTAL% parts into this folder and then extract.
echo Press 1 to proceed, or Q to quit.
choice /c 1Q /n
if errorlevel 2 ( echo Quit chosen. Exiting. & goto :end )

REM ===== DOWNLOAD =====
echo.
echo [INFO] Starting downloads into: "%WORK%"
echo.

set /a DONE=0
for /f "usebackq tokens=1,2 delims=|" %%i in ("%TMP_URLS%") do (
  set "FNAME=%%i"
  set "URL=%%j"
  set "DEST=%WORK%\!FNAME!"

  echo --------------------------------------------------------------
  echo [DL] !FNAME!

  if defined CURL (
    "%CURL%" -L --retry 5 --retry-delay 2 -C - -# -H "User-Agent: P4G-Downloader" -o "!DEST!" "!URL!"
    if errorlevel 1 (
      echo [WARN] curl failed for !FNAME!
    ) else (
      set /a DONE+=1
      echo [OK] Downloaded
    )
  ) else (
    powershell -NoProfile -Command ^
      "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "$u='%URL%';$o='%DEST%';" ^
      "for($t=1;$t -le 5;$t++){try{Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='curl/8.0'} -Uri $u -OutFile $o;break}catch{Start-Sleep -Seconds 3}}"
    if errorlevel 1 (
      echo [WARN] PowerShell download failed: !FNAME!
    ) else (
      set /a DONE+=1
      echo [OK] Downloaded
    )
  )
)

echo.
echo [INFO] Downloaded %DONE% / %COUNT_TOTAL%.

REM Verify non-zero
set /a OKCOUNT=0
for /f "usebackq tokens=1,2 delims=|" %%i in ("%TMP_URLS%") do (
  if exist "%WORK%\%%i" for %%S in ("%WORK%\%%i") do if %%~zS GTR 0 set /a OKCOUNT+=1
)
echo [INFO] Verified %OKCOUNT% / %EXPECT_TOTAL% files present and non-empty.
if not %OKCOUNT%==%EXPECT_TOTAL% (
  echo [ERROR] Some parts are missing/zero-byte. Re-run to resume.
  pause & goto :end
)

REM ===== EXTRACT =====
echo.
echo [INFO] Locating first volume...
set "FIRSTPART=%WORK%Persona 4 Golden.part001.rar"
if not exist "%FIRSTPART%" (
  for %%P in ("%WORK%\*part001*.rar" "%WORK%\*part01*.rar" "%WORK%\*.rar") do (
    if not defined FIRSTPART set "FIRSTPART=%%~fP"
  )
)
if not defined FIRSTPART (
  echo [ERROR] No .rar files found to extract.
  pause & goto :PROMPT_DELETE   REM still go to prompt so user can delete partials
)

set "EXTRACT_LOG=%WORK%unrar_extract.log"
echo [INFO] First volume: %FIRSTPART%
echo [INFO] Extracting into: "%WORK%"
echo [INFO] Logging to: %EXTRACT_LOG%

"%UNRAR%" x -y -o+ -idq "%FIRSTPART%" "%WORK%" > "%EXTRACT_LOG%" 2>&1
set "UNRAR_RC=%ERRORLEVEL%"

if %UNRAR_RC% GEQ 2 (
  echo [ERROR] Extraction failed. (unrar exit code %UNRAR_RC%)
  echo --- Last 40 lines of %EXTRACT_LOG% ---
  powershell -NoProfile -Command ^
    "$ErrorActionPreference='SilentlyContinue'; if (Test-Path '%EXTRACT_LOG%') { Get-Content -Tail 40 -Path '%EXTRACT_LOG%' }"
  echo --------------------------------------
  REM even on failure we still offer cleanup
  goto :PROMPT_DELETE
) else (
  if %UNRAR_RC% EQU 1 (
    echo [WARN] UnRAR finished with warnings (code 1). Files likely extracted OK.
  ) else (
    echo [OK] Extraction completed successfully.
  )
)

:PROMPT_DELETE
echo.
call :PROMPT_YN "Delete downloaded .rar parts?" ANSW
if /i "%ANSW%"=="N" (
  echo Keeping parts.
  goto :end
)

REM ===== CLEANUP =====
set /a DELCOUNT=0

REM 1) Delete via URL list
if exist "%TMP_URLS%" (
  for /f "usebackq tokens=1 delims=|" %%i in ("%TMP_URLS%") do (
    if exist "%WORK%\%%i" (
      del /q "%WORK%\%%i" 2>nul
      if not exist "%WORK%\%%i" set /a DELCOUNT+=1
    )
  )
)

REM 2) Delete any leftover 3-digit parts (safety net)
for %%P in ("%WORK%Persona 4 Golden.part???.rar") do (
  if exist "%%~fP" (
    del /q "%%~fP" 2>nul
    if not exist "%%~fP" set /a DELCOUNT+=1
  )
)

echo 🧹 Removed %DELCOUNT% .rar file(s).

:end
del "%TMP_LIST%" 2>nul
del "%TMP_URLS%" 2>nul
echo.
echo All done.
pause
exit /b 0

REM ================= helpers =================
:COLLECT
REM %1 = BRANCH, %2 = EXPECTED_COUNT
setlocal EnableDelayedExpansion
set "BRANCH=%~1"
set "EXPECT=%~2"

if "%PATH_ENC%"=="" (
  set "API_URL=https://api.github.com/repos/%OWNER%/%REPO%/contents?ref=%BRANCH%"
  set "HTML_URL=https://github.com/%OWNER%/%REPO%/tree/%BRANCH%"
) else (
  set "API_URL=https://api.github.com/repos/%OWNER%/%REPO%/contents/%PATH_ENC%?ref=%BRANCH%"
  set "HTML_URL=https://github.com/%OWNER%/%REPO%/tree/%BRANCH%/%PATH_RAW%"
)

echo [INFO] Listing %BRANCH% …
break > "%TMP_LIST%" 2>nul

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
  "try{" ^
  "  $r=Invoke-RestMethod -Headers @{'User-Agent'='P4G-Downloader'} -UseBasicParsing -Uri '%API_URL%';" ^
  "  $files=$r | Where-Object { $_.type -eq 'file' -and $_.name -match '\.rar$' } | Sort-Object name;" ^
  "  foreach($f in $files){ '{0}|{1}' -f $f.name,$f.download_url }" ^
  "}catch{ exit 1 }" > "%TMP_LIST%"

if errorlevel 1 (
  echo   [WARN] API failed/empty on %BRANCH%. Trying HTML fallback…
  powershell -NoProfile -Command ^
    "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
    "$u='%HTML_URL%';$h=Invoke-WebRequest -Headers @{'User-Agent'='P4G-Downloader'} -UseBasicParsing -Uri $u;" ^
    "$links=$h.Links | Where-Object href -match '/%OWNER%/%REPO%/blob/%BRANCH%/.+\.rar$';" ^
    "foreach($l in $links){" ^
    "  $name=[System.Web.HttpUtility]::UrlDecode(($l.href -split '/')[-1]);" ^
    "  $raw=$l.href -replace '/blob/','/raw/';" ^
    "  '{0}|https://github.com{1}' -f $name,$raw" ^
    "}" > "%TMP_LIST%"
)

if not exist "%TMP_LIST%" (
  echo   [ERROR] Could not list files for %BRANCH%.
  endlocal & exit /b 2
)

set /a COUNT_THIS=0
for /f "usebackq delims=" %%L in ("%TMP_LIST%") do (
  >>"%TMP_URLS%" echo %%L
  set /a COUNT_THIS+=1
)
echo   [INFO] %BRANCH%: found !COUNT_THIS! .rar file(s)
if not "!COUNT_THIS!"=="%EXPECT%" (
  echo   [ERROR] Expected %EXPECT% parts on %BRANCH% but found !COUNT_THIS!.
  endlocal & exit /b 3
)

endlocal & exit /b 0

:PROMPT_YN
REM %1 = question, %2 = OUTVAR (Y/N). Uses CHOICE if present, else SET /P.
setlocal EnableExtensions
set "Q=%~1"
where choice >nul 2>&1
if %ERRORLEVEL% EQU 0 (
  choice /m "%Q%" /c YN /n
  if errorlevel 2 (set "A=N") else (set "A=Y")
) else (
  set "A="
  :ask
  set /p A=%Q% [Y/N]: 
  if /i not "%A%"=="Y" if /i not "%A%"=="N" goto :ask
)
endlocal & set "%~2=%A%"
exit /b 0

:hard_fail
echo.
echo [ERROR] Listing failed for one of the branches.
pause
exit /b 1
