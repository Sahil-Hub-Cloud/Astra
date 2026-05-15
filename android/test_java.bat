@echo off
setlocal
set "JAVA_HOME=C:\PROGRA~1\Android\ANDROI~1\jbr"
set "JAVA_EXE=%JAVA_HOME%\bin\java.exe"
echo Checking JAVA_EXE path: %JAVA_EXE%
if exist "%JAVA_EXE%" (
    echo FOUND java.exe
    "%JAVA_EXE%" -version
) else (
    echo NOT FOUND java.exe
)
endlocal
