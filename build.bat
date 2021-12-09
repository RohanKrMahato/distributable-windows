@echo off

rem Use all the cores when building
set CL=/MP

mkdir metacall
cd metacall
set loc=%cd%

mkdir %loc%\runtimes
mkdir %loc%\runtimes\ruby
mkdir %loc%\runtimes\python
mkdir %loc%\runtimes\dotnet
mkdir %loc%\runtimes\nodejs

mkdir %loc%\dependencies
cd %loc%\dependencies

echo Checking Compiler and Build System

where /Q cmake
if %ERRORLEVEL% EQU 0 (goto skip_build_system)

rem Install CMake if not found
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-windows-x86_64.zip', './cmake.zip')"
powershell -Command "$global:ProgressPreference = 'SilentlyContinue'; Expand-Archive" -Path "cmake.zip" -DestinationPath .
set PATH=%PATH%;%loc%\cmake-3.22.1-windows-x86_64\bin
del cmake.zip

:skip_build_system

echo Downloading Dependencies

mkdir %loc%\dependencies
cd %loc%\dependencies
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://github.com/MSP-Greg/ruby-loco/releases/download/ruby-master/ruby-mswin.7z', './ruby-mswin.7z')"
@REM powershell -Command "(New-Object Net.WebClient).DownloadFile('https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe', './python_installer.exe')"
@REM powershell -Command "(New-Object Net.WebClient).DownloadFile('https://download.visualstudio.microsoft.com/download/pr/d1ca6dbf-d054-46ba-86d1-36eb2e455ba2/e950d4503116142d9c2129ed65084a15/dotnet-sdk-5.0.403-win-x64.zip', './dotnet_sdk.zip')"
@REM powershell -Command "(New-Object Net.WebClient).DownloadFile('https://nodejs.org/download/release/v14.18.2/node-v14.18.2-win-x64.zip', './node.zip')"

echo Installing Runtimes

mkdir %loc%\runtimes
mkdir %loc%\runtimes\ruby
mkdir %loc%\runtimes\python
mkdir %loc%\runtimes\dotnet
mkdir %loc%\runtimes\nodejs

cd %loc%\dependencies

rem Install 7zip (PowerShell) for Ruby
powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Install-PackageProvider" -Name NuGet -MinimumVersion 2.8.5.201 -Force; Set-PSRepository -Name 'PSGallery' -SourceLocation "https://www.powershellgallery.com/api/v2" -InstallationPolicy Trusted
powershell -Command "Install-Module" -Name 7Zip4PowerShell -Force

rem Install Ruby
powershell -Command "Expand-7Zip" -ArchiveFileName "ruby-mswin.7z" -DestinationPath "%loc%\runtimes\dotnet" -Remove
robocopy /move /e %loc%\runtimes\ruby\ruby-mswin %loc%\runtimes\ruby /NFL /NDL /NJH /NJS /NC /NS /NP
rmdir %loc%\runtimes\ruby\ruby-mswin
set PATH=%PATH%;%loc%\runtimes\ruby\bin

@REM rem Install Python
@REM python_installer.exe /quiet TargetDir="%loc%\runtimes\python" PrependPath=1 CompileAll=1
@REM set PATH=%PATH%;%loc%\runtimes\python\bin

@REM rem Install DotNet
@REM powershell -Command "$global:ProgressPreference = 'SilentlyContinue'; Expand-Archive" -Path "dotnet_sdk.zip" -DestinationPath %loc%\runtimes\dotnet
@REM set PATH=%PATH%;%loc%\runtimes\dotnet\bin

@REM rem Install NodeJS
@REM powershell -Command "$global:ProgressPreference = 'SilentlyContinue'; Expand-Archive" -Path "node.zip" -DestinationPath %loc%\runtimes\nodejs
@REM robocopy /move /e %loc%\runtimes\nodejs\node-v14.18.2-win-x64 %loc%\runtimes\nodejs /NFL /NDL /NJH /NJS /NC /NS /NP
@REM rmdir %loc%\runtimes\nodejs\node-v14.18.2-win-x64
@REM set PATH=%PATH%;%loc%\runtimes\nodejs\bin

echo Building MetaCall

cd ..

git clone --depth 1 https://github.com/metacall/core.git

rem Patch for FindRuby.cmake
set "escaped_loc=%loc:\=/%"

echo set(Ruby_VERSION 3.1.0)>> %loc%\core\cmake\FindRuby.cmake
echo set(Ruby_ROOT_DIR "%escaped_loc%/runtimes/ruby")>> %loc%\core\cmake\FindRuby.cmake
echo set(Ruby_EXECUTABLE "%escaped_loc%/runtimes/ruby/bin/ruby.exe")>> %loc%\core\cmake\FindRuby.cmake
echo set(Ruby_INCLUDE_DIRS "%escaped_loc%/runtimes/ruby/include/ruby-3.1.0;%escaped_loc%/runtimes/ruby/include/ruby-3.1.0/x64-mswin64_140")>> %loc%\core\cmake\FindRuby.cmake
echo set(Ruby_LIBRARY "%escaped_loc%/runtimes/ruby/lib/x64-vcruntime140-ruby310.lib")>> %loc%\core\cmake\FindRuby.cmake
echo include(FindPackageHandleStandardArgs)>> %loc%\core\cmake\FindRuby.cmake
echo FIND_PACKAGE_HANDLE_STANDARD_ARGS(Ruby REQUIRED_VARS Ruby_EXECUTABLE Ruby_LIBRARY Ruby_INCLUDE_DIRS VERSION_VAR Ruby_VERSION)>> %loc%\core\cmake\FindRuby.cmake
echo mark_as_advanced(Ruby_EXECUTABLE Ruby_LIBRARY Ruby_INCLUDE_DIRS)>> %loc%\core\cmake\FindRuby.cmake

mkdir core\build
cd core\build

rem TODO: NODE, CS, RB, TS
cmake -Wno-dev ^
	-DCMAKE_BUILD_TYPE=Release ^
	-DOPTION_BUILD_SECURITY=OFF ^
	-DOPTION_FORK_SAFE=OFF ^
	-DOPTION_BUILD_SCRIPTS=OFF ^
	-DOPTION_BUILD_TESTS=OFF ^
	-DOPTION_BUILD_EXAMPLES=OFF ^
	-DOPTION_BUILD_LOADERS_PY=ON ^
	-DPython_ROOT_DIR="%loc%\runtimes\python" ^
	-DOPTION_BUILD_LOADERS_NODE=OFF ^
	-DOPTION_BUILD_LOADERS_CS=OFF ^
	-DOPTION_BUILD_LOADERS_RB=ON ^
	-DOPTION_BUILD_LOADERS_TS=OFF ^
	-DCMAKE_INSTALL_PREFIX="%loc%" ^
	-G "NMake Makefiles" ..
cmake --build . --target install
cd ..\..

rem Delete unnecesary data
rmdir /S /Q %loc%\core
rmdir /S /Q %loc%\dependencies
rmdir /S /Q %loc%\cmake-3.22.1-windows-x86_64
rmdir /S /Q %loc%\w64devkit

echo MetaCall Built Successfully
