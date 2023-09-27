@echo off
cls

for /f "Tokens=1-4 Delims=/ " %%i in ('date /t') do  set dt=%%i-%%j-%%k

set WorkDrv=D:
set WorkDir=%WorkDrv%\Scripts
set LogPath=%WorkDrv%\Scripts\Log

%WorkDrv%
cd %WorkDir%

if not exist G:\NUL net use G: \\fs01\data\Global
if not exist S:\NUL net use S: \\fs01\data\Shared
if not exist Y:\NUL net use Y: \\fs01\data\Users

robocopy G: F:\Data\Global /MIR /SEC /FFT /Z /R:10 /W:5 /LOG:"%LogPath%\%dt%-Global.Log"
bin\zip %LogPath%\%dt%-Global.Log.zip %LogPath%\%dt%-Global.Log
del %LogPath%\%dt%-Global.Log

robocopy Y: F:\Data\Users /MIR /SEC /FFT /Z /R:10 /W:5 /LOG:"%LogPath%\%dt%-Users.Log"
bin\zip %LogPath%\%dt%-Users.Log.zip %LogPath%\%dt%-Users.Log
del %LogPath%\%dt%-Users.Log

robocopy S: F:\Data\Shared /MIR /SEC /FFT /Z /R:10 /W:5 /LOG:"%LogPath%\%dt%-Shared.Log"
bin\zip %LogPath%\%dt%-Shared.Log.zip %LogPath%\%dt%-Shared.Log
del LogPath%\%dt%-Shared.Log
