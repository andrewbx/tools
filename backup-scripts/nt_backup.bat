@echo off
cls

rem *** Point to backup store (Destination)

set backup_loc=D:\Backups\Backups

rem *** Backup working folder

set backup_run=D:\Backups

rem *** Don't change anything below

set logfile_loc=%backup_run%\Logs
set select_loc=%backup_run%\Selection
set backup_log="%userprofile%\Local Settings\Application Data\Microsoft\Windows NT\NTBackup\data"
set backup_cat="%allusersprofile%\Application Data\Microsoft\Windows NT\NTBackup\catalogs51"

cd %backup_run%

if not exist %backup_loc%\Week1\nul mkdir %backup_loc%\Week1
if not exist %backup_loc%\Week2\nul mkdir %backup_loc%\Week2

echo.
echo *** Calculating date and time for backup

for /f "Tokens=1-3 Delims=/ " %%i in ('date /t') do set dt=%%i-%%j-%%k
for /f "Tokens=1" %%i in ('time /t') do set tm=-%%i
set tm=%tm::=-%
set dtt=%dt%%tm%

for /f "tokens=1" %%f in ('Bin\date') do set dayofweek=%%f

:start_backup

echo *** Running backup

%systemroot%\system32\ntbackup.exe backup "@%select_loc%\Selections.bks" /a /d "%dt%-CO-Backup" /v:no /r:no /rs:no /hc:on /m normal /j "%dtt%" /l:f /f "%backup_loc%\%dayofweek%-CO-Backup.bkf"

echo *** Copying log file

dir /b /O:-d %backup_log% > log.tmp
for /f "tokens=1" %%f in ('Bin\head.exe -1 log.tmp') do copy /y %backup_log%\%%f %logfile_loc%\%dt%-CO-Backup.log >NUL
del log.tmp

echo *** Backup completed

if "%dayofweek%" NEQ "Sun" goto end

:check_backups

set /a inc=0
For /f %%f in ('dir %backup_loc%\*.bkf') do set /A inc+=1

echo *** Rotating backups for last week
if /I %inc% LSS 7 goto end
if exist %backup_loc%\Week1\*.bkf move %backup_loc%\Week1\*.bkf %backup_loc%\Week2 >NUL

echo *** Rotating backups for current week
dir /b /O:d %backup_loc%\*.bkf > loc.tmp
for /f "tokens=1" %%f in ('Bin\head.exe -%inc% loc.tmp') do move %backup_loc%\%%f %backup_loc%\Week1 >NUL
del loc.tmp

:check_catalogs

set /a inc=0
For /f %%f in ('dir /b %backup_cat%\*.V01') do set /A inc+=1
dir /b /O:d %backup_cat%\*.V01 > cat.tmp

echo *** Deleting catalog files for last 7 days
for /f "tokens=1" %%f in ('Bin\head.exe -%inc% cat.tmp') do del %backup_cat%\%%f
del cat.tmp

:check_logs

set /a inc=0
For /f %%f in ('dir /b %backup_log%\*.log') do set /A inc+=1
if /I %inc% LSS 14 goto end

echo *** Deleting log files older than 14 days
dir /b /O:d %backup_loc%\*.log > log.tmp
for /f "tokens=1" %%f in ('Bin\head.exe -%inc% logs.tmp') do del %logfile_loc%\%%f 
del logs.tmp 

:end

echo.
exit