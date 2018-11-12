param([string]$CMAKE_TOOLSET="v141")
# https://stackoverflow.com/questions/5592531/how-to-pass-an-argument-to-a-powershell-script 

$CMAKE_GENERATOR = "Visual Studio 15 2017 Win64"
$env:JAVA_HOME = "C:\\Program Files\\Java\\jdk1.8.0"
# Note: python 2.7 32bit is already on the path. We want v2.7 64bit,
# so we must add v2.7 64bit earlier on the PATH so that CMake finds it when
# configuring.
$PYTHON_DIR = "C:\\Python27-x64"
# Used by FindAnt.cmake:
$env:ANT_HOME = "C:\\Program Files\\NetBeans 8.2\\extide\\ant"
$NSIS_DIR = "C:\\Program Files (x86)\\NSIS"

$env:Path = "$PYTHON_DIR;$env:PATH"
$OPENSIM_CORE_SOURCE_DIR = "$pwd\opensim-core"
$OPENSIM_CORE_BUILD_DIR = "$pwd\opensim-core-build"
$OPENSIM_CORE_INSTALL_DIR = "$pwd\opensim-core-install"
$OPENSIM_CORE_DEP_SOURCE_DIR = "$OPENSIM_CORE_SOURCE_DIR\dependencies"
$OPENSIM_CORE_DEP_BUILD_DIR = "$pwd\opensim-core-dep-build"
$OPENSIM_CORE_DEP_INSTALL_DIR = "$pwd\opensim-core-dep-install"
$OPENSIM_GUI_SOURCE_DIR = "$pwd\opensim-gui"
$OPENSIM_GUI_BUILD_DIR = "$pwd\opensim-gui-build"
# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_environment_variables?view=powershell-6
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
$env:Path = "$NSIS_DIR;$env:Path"

[xml]$xml = Get-Content git_tags.xml
$OPENSIM_CORE_GIT_TAG = $xml.info.opensim_core_git_tag
$OPENSIM_GUI_GIT_TAG = $xml.info.opensim_gui_git_tag

## Obtain opensim-core source code.
# TODO should we clone the git repo instead of downloading a zip? Does CMake
# extract any information from the git repo?
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$OPENSIM_CORE_ZIP = "$OPENSIM_CORE_GIT_TAG.zip"
$OPENSIM_CORE_ARCHIVE_URL = "https://github.com/opensim-org/opensim-core/archive/$OPENSIM_CORE_ZIP"
(New-Object System.Net.WebClient).DownloadFile($OPENSIM_CORE_ARCHIVE_URL, "$pwd\$OPENSIM_CORE_ZIP")
& "C:\Program Files\7-Zip\7z.exe" x $OPENSIM_CORE_ZIP
mv opensim-core-$OPENSIM_CORE_GIT_TAG $OPENSIM_CORE_SOURCE_DIR
dir $OPENSIM_CORE_SOURCE_DIR

## Superbuild dependencies. 
mkdir $OPENSIM_CORE_DEP_BUILD_DIR
cd $OPENSIM_CORE_DEP_BUILD_DIR
# The backtick is line continuation, but make sure there is no whitespace
# after the backtick!
cmake "$OPENSIM_CORE_DEP_SOURCE_DIR" `
    -G"$CMAKE_GENERATOR" `
    -T"$CMAKE_TOOLSET" `
    -DCMAKE_INSTALL_PREFIX="$OPENSIM_CORE_DEP_INSTALL_DIR" `
    -DSUPERBUILD_simbody=ON
cmake --build . --config Release -- /maxcpucount:4 /verbosity:quiet
mkdir $OPENSIM_CORE_BUILD_DIR
## Configure and build OpenSim.
cd $OPENSIM_CORE_BUILD_DIR
# Configure.
# Set the CXXFLAGS environment variable to turn warnings into errors.
cmake -E env CXXFLAGS="/WX" `
    cmake "$OPENSIM_CORE_SOURCE_DIR" `
        -G"$CMAKE_GENERATOR" `
        -T"$CMAKE_TOOLSET" `
        -DOPENSIM_DEPENDENCIES_DIR="$OPENSIM_CORE_DEP_INSTALL_DIR" `
        -DCMAKE_INSTALL_PREFIX="$OPENSIM_CORE_INSTALL_DIR" `
        -DBUILD_JAVA_WRAPPING=ON `
        -DBUILD_PYTHON_WRAPPING=ON `
        -DWITH_BTK:BOOL=ON

# Build.
cmake --build . --target doxygen --config Release
cmake --build . --config Release -- /maxcpucount:4 /verbosity:quiet
cmake --build . --target install --config Release -- /maxcpucount:4 /verbosity:quiet

# Obtain opensim-gui source code.
git clone https://github.com/opensim-org/opensim-gui $OPENSIM_GUI_SOURCE_DIR
cd $OPENSIM_GUI_SOURCE_DIR
git checkout $OPENSIM_GUI_GIT_TAG
# TODO how to handle tags for these submodules?
git submodule update --init --recursive -- `
    opensim-models `
    opensim-visualizer `
    Gui/opensim/threejs


# Build opensim-gui.
mkdir $OPENSIM_GUI_BUILD_DIR
cd $OPENSIM_GUI_BUILD_DIR
cmake $OPENSIM_GUI_SOURCE_DIR `
    -G"$CMAKE_GENERATOR" `
    -T"$CMAKE_TOOLSET" `
    -DCMAKE_PREFIX_PATH="$OPENSIM_CORE_INSTALL_DIR" `
    -DANT_ARGS="-Dnbplatform.default.netbeans.dest.dir=C:/Program Files/NetBeans 8.2;-Dnbplatform.default.harness.dir=C:/Program Files/NetBeans 8.2/harness"
cmake --build . --target CopyOpenSimCore --config Release
cmake --build . --target CopyModels --config Release
cmake --build . --target PrepareInstaller --config Release
cmake --build . --target CopyJRE --config Release
cmake --build . --target CopyVisualizer --config Release


# Create files to distribute.
mkdir $env:APPVEYOR_BUILD_FOLDER\release
cd $env:APPVEYOR_BUILD_FOLDER\release
# TODO use shortened git commit if not using a tag.
$OPENSIM_CORE_SOURCE_ZIP = "$env:APPVEYOR_BUILD_FOLDER\release\OpenSimCore-$OPENSIM_CORE_GIT_TAG-source.zip"
& "C:\Program Files\7-Zip\7z.exe" a "$OPENSIM_CORE_SOURCE_ZIP" "$OPENSIM_CORE_INSTALL_DIR"

# TODO ResourceHacker. Or can NSIS set the application icon for us?
# TODO Visual C++ redistributable.
# https://docs.microsoft.com/en-us/cpp/ide/determining-which-dlls-to-redistribute
# 
cd $OPENSIM_GUI_SOURCE_DIR\Gui\opensim\dist\installer\
makensis $OPENSIM_GUI_SOURCE_DIR\Gui\opensim\dist\installer\make_installer.nsi
mv $OPENSIM_GUI_SOURCE_DIR\Gui\opensim\dist\installer\*.exe `
    $env:APPVEYOR_BUILD_FOLDER\release\

$OPENSIM_GUI_ZIP = "$env:APPVEYOR_BUILD_FOLDER\release\OpenSim-$OPENSIM_GUI_GIT_TAG.zip"
& "C:\Program Files\7-Zip\7z.exe" a "$OPENSIM_GUI_ZIP" "$OPENSIM_GUI_SOURCE_DIR\Gui\opensim\dist\installer\opensim\"




