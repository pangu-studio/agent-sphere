@echo off
setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0..
set BUILD_DIR=%PROJECT_DIR%\build\x64-release

:: Read version from the single-source-of-truth VERSION file
set /p VERSION=<"%PROJECT_DIR%\VERSION"

if "%VERSION%"=="" (
    echo ERROR: Could not read version from %PROJECT_DIR%\VERSION
    exit /b 1
)
echo Building AgentSphere v%VERSION% MSI installer (NO SIGNING)...

:: Initialize VS build environment (cmake, ninja, cl, etc.)
set VSWHERE="%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "delims=" %%i in ('%VSWHERE% -latest -property installationPath') do set VS_PATH=%%i
if not exist "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" (
    echo ERROR: Could not find vcvarsall.bat. Is Visual Studio installed?
    exit /b 1
)
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" x64

:: Add VS-bundled cmake to PATH (VS 2022 ships with CMake 3.30+)
set CMAKE_PATH=%VS_PATH%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin
if exist "%CMAKE_PATH%\cmake.exe" (
    set "PATH=%CMAKE_PATH%;%PATH%"
)

:: Add .NET global tools to PATH (wix, dotnet-etc.) - DEPRECATED: use system WiX
:: set "DOTNET_TOOLS=%USERPROFILE%\.dotnet\tools"
:: if exist "%DOTNET_TOOLS%\wix.exe" (
::     set "PATH=%DOTNET_TOOLS%;%PATH%"
:: )

:: Add system WiX Toolset to PATH (v6.0 installed via MSI)
set "WIX_PATH=C:\Program Files\WiX Toolset v6.0\bin"
if exist "%WIX_PATH%\wix.exe" (
    set "PATH=%WIX_PATH%;%PATH%"
)

:: Step 1: CMake configure + build (RelWithDebInfo)
echo.
echo [1/3] CMake RelWithDebInfo build...
cmake -S "%PROJECT_DIR%" -B "%BUILD_DIR%" -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo
if errorlevel 1 (
    echo ERROR: CMake configure failed.
    exit /b 1
)

cmake --build "%BUILD_DIR%" --config RelWithDebInfo
if errorlevel 1 (
    echo ERROR: CMake build failed.
    exit /b 1
)

:: Verify WinSparkle.dll was copied to build dir by CMake post-build step
if not exist "%BUILD_DIR%\WinSparkle.dll" (
    echo ERROR: WinSparkle.dll not found in build directory.
    exit /b 1
)

:: Step 2: Build MSI with WiX (skip signing)
echo.
echo [2/3] Building MSI with WiX (no signing)...
where wix >nul 2>&1
if errorlevel 1 (
    echo ERROR: wix.exe not found in PATH. Install with: dotnet tool install -g wix
    exit /b 1
)
wix build "%PROJECT_DIR%\installer\TenBox.wxs" ^
    "%PROJECT_DIR%\installer\zh-CN.wxl" ^
    -arch x64 ^
    -culture zh-CN ^
    -ext WixToolset.UI.wixext ^
    -ext WixToolset.Util.wixext ^
    -d ProductVersion=%VERSION% ^
    -d BuildDir=%BUILD_DIR% ^
    -d ProjectDir=%PROJECT_DIR% ^
    -o "%BUILD_DIR%\AgentSphere_%VERSION%_nosign.msi"
if errorlevel 1 (
    echo ERROR: WiX build failed.
    exit /b 1
)

echo.
echo [3/3] Done!
echo Success: %BUILD_DIR%\AgentSphere_%VERSION%_nosign.msi
echo WARNING: This installer is NOT signed. For internal testing only.
