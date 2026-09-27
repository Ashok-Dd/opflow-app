@echo off
rem ---------------------------------------------------------------------------
rem OPflow: rebuild and send out the app after you change it.
rem
rem   Double-click, or run from a terminal:
rem     deploy.bat          web link + Android APK
rem     deploy.bat web      only the web link (Vercel)
rem     deploy.bat apk      only the Android APK
rem
rem   First time only: run "npx vercel@latest login" once.
rem ---------------------------------------------------------------------------
setlocal
cd /d "%~dp0"

set "WHAT=%~1"
if "%WHAT%"=="" set "WHAT=all"

if /i "%WHAT%"=="apk" goto apk

:web
echo.
echo === 1. Building the web version ===
rem The live server (Render). iPhone users use this web version: https://opflow-alpha.vercel.app
call flutter build web --release --dart-define=BACKEND=api --dart-define=API_BASE_URL=https://opflow-backend.onrender.com
if errorlevel 1 goto failed

rem Vercel remembers the project in build\web\.vercel, which a rebuild can remove.
rem Keep a copy next to this script and put it back before deploying.
if exist ".vercel-link\project.json" (
  if not exist "build\web\.vercel" mkdir "build\web\.vercel"
  copy /y ".vercel-link\*" "build\web\.vercel\" >nul
)

echo.
echo === 2. Putting it online (Vercel) ===
echo First time? Answer: Link to existing project = N, name = opflow-demo, directory = ./
echo Later, if it asks again: Link to existing project = Y, pick opflow-demo.
pushd "build\web"
call npx vercel@latest --prod
set "VERCEL_ERR=%errorlevel%"
popd
if not "%VERCEL_ERR%"=="0" goto failed

if exist "build\web\.vercel\project.json" (
  if not exist ".vercel-link" mkdir ".vercel-link"
  copy /y "build\web\.vercel\*" ".vercel-link\" >nul
)
echo Web link updated. Same link as before, nothing new to send.

if /i "%WHAT%"=="web" goto done

:apk
echo.
echo === 3. Building the Android APK ===
call flutter build apk --release
if errorlevel 1 goto failed
if not exist "release" mkdir "release"
copy /y "build\app\outputs\flutter-apk\app-release.apk" "release\OPflow.apk" >nul
echo APK ready: %~dp0release\OPflow.apk
echo Send this file on WhatsApp. People who have the app tap it and choose Update.
explorer "%~dp0release"

:done
echo.
echo All done.
pause
exit /b 0

:failed
echo.
echo Something went wrong. Read the message above, fix it, and run deploy.bat again.
pause
exit /b 1
