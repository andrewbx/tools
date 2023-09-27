@echo off
cls

set company="CompanyName"
set email="syslog@email-address"
set email_server="localhost"
set server="DOMAIN-SVR-01"
set rsync_server="rsync.remote.host"
set rsync_folder="Backup/Computers/%server%"
set rsync_bin="%ProgramFiles%\cwrsync\bin\rsync"

for /f "Tokens=1-4 Delims=/ " %%i in ('date /t') do  set dt=%%i-%%j-%%k-%%l
for /f "Tokens=1" %%i in ('time /t') do set tm=-%%i
set tm=%tm::=-%
set dtt=%dt%%tm%

echo.
echo *** Running Remote Backup.

D:
cd \
%rsync_bin% -vvurpogtlH --delete --ignore-errors --exclude="share\work" "home" "shared" "company" rsync://%rsync_server%/%rsync_folder% > C:\Remote\rsync.%dtt%.log

echo.
echo *** Syncronisation Complete.
echo *** Mailing log to: %email%
echo.

C:
cd Remote
blat rsync.%dtt%.log -to %email% -server %email_server% -f backup@company.net -subject "[%dtt%] %server% %company% Remote Backup (Daily)"
del rsync.%dtt%.log
