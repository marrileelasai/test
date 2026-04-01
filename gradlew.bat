@rem ##########################################################################
@rem  Gradle startup script for Windows
@rem ##########################################################################
@if "%DEBUG%"=="" @echo off
@rem Set local scope for the variables with windows NT shell
if "%OS%"=="Windows_NT" setlocal
set DIRNAME=%~dp0
if "%DIRNAME%"=="" set DIRNAME=.
set APP_BASE_NAME=%~n0
set APP_HOME=%DIRNAME%
set CLASSPATH=%APP_HOME%\gradle\wrapper\gradle-wrapper.jar
@rem Find java.exe
if defined JAVA_HOME goto findJavaFromJavaHome
echo.
echo ERROR: JAVA_HOME is not set and no 'java' command could be found in your PATH.
echo Please set the JAVA_HOME variable in your environment to match the
echo location of your Java installation.
goto fail
:findJavaFromJavaHome
set JAVA_HOME=%JAVA_HOME:"=%
set JAVA_EXE=%JAVA_HOME%/bin/java.exe
if exist "%JAVA_EXE%" goto execute
echo.
echo ERROR: JAVA_HOME is set to an invalid directory: %JAVA_HOME%
echo Please set the JAVA_HOME variable to match the location of your Java installation.
goto fail
:execute
"%JAVA_EXE%" -classpath "%CLASSPATH%" org.gradle.wrapper.GradleWrapperMain %*
:end
if "%ERRORLEVEL%"=="0" goto mainEnd
:fail
rem Set variable GRADLE_EXIT_CONSOLE if you need the _script_ return code instead of the _cmd_ return code!
if not "" == "%GRADLE_EXIT_CONSOLE%" exit 1
exit /b 1
:mainEnd
if "%OS%"=="Windows_NT" endlocal
:omega
