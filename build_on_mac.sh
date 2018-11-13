BASE_DIR=$(pwd)
STAGE=0 # 0 means build all.
# 1 means only build opensim-core dependencies
# 2 means only build opensim-core
# 3 means only build GUI.
# Exit script if a command fails.
set -e
while getopts b:s: option
do
    case "${option}"
        in
        b) BASE_DIR=${OPTARG};;
        s) STAGE=${OPTARG};;
    esac
done

BTYPE=Release
OSX_TARGET=10.10
SWIG_VER=3.0.8
SWIG_DIR=$BASE_DIR/swig
OPENSIM_CORE_SOURCE_DIR="$BASE_DIR/opensim-core"
OPENSIM_CORE_BUILD_DIR="$BASE_DIR/opensim-core-build"
OPENSIM_CORE_INSTALL_DIR="$BASE_DIR/opensim-core-install"
OPENSIM_CORE_DEP_SOURCE_DIR="$OPENSIM_CORE_SOURCE_DIR/dependencies"
OPENSIM_CORE_DEP_BUILD_DIR="$BASE_DIR/opensim-core-dep-build"
OPENSIM_CORE_DEP_INSTALL_DIR="$BASE_DIR/opensim-core-dep-install"
OPENSIM_GUI_SOURCE_DIR="$BASE_DIR/opensim-gui"
OPENSIM_GUI_BUILD_DIR="$BASE_DIR/opensim-gui-build"

OPENSIM_CORE_GIT_TAG="$(xmllint --xpath "//info/opensim_core_git_tag/text()" git_tags.xml)"
OPENSIM_GUI_GIT_TAG="$(xmllint --xpath "//info/opensim_gui_git_tag/text()" git_tags.xml)"

if [[ $STAGE -eq 0 || $STAGE -eq 1 ]]
then

    ## Obtain opensim-core source code.
    OPENSIM_CORE_ZIP="$OPENSIM_CORE_GIT_TAG.zip"
    wget https://github.com/opensim-org/opensim-core/archive/$OPENSIM_CORE_ZIP
    unzip $OPENSIM_CORE_ZIP
    mv opensim-core-$OPENSIM_CORE_GIT_TAG $OPENSIM_CORE_SOURCE_DIR
    
    ## Superbuild dependencies. 
    mkdir $OPENSIM_CORE_DEP_BUILD_DIR
    cd $OPENSIM_CORE_DEP_BUILD_DIR
    DEP_CMAKE_ARGS=($OPENSIM_CORE_DEP_SOURCE_DIR -DCMAKE_INSTALL_PREFIX=$OPENSIM_CORE_DEP_INSTALL_DIR -DCMAKE_BUILD_TYPE=$BTYPE)
    DEP_CMAKE_ARGS+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=$OSX_TARGET)
    
    printf '%s\n' "${DEP_CMAKE_ARGS[@]}"
    cmake "${DEP_CMAKE_ARGS[@]}"
    make -j4

fi


if [[ $STAGE -eq 0 || $STAGE -eq 2 ]]
then

    # Install SWIG.
    mkdir $BASE_DIR/swig-source && cd $BASE_DIR/swig-source
    wget https://github.com/swig/swig/archive/rel-$SWIG_VER.tar.gz
    tar xzf rel-$SWIG_VER.tar.gz && cd swig-rel-$SWIG_VER
    sh autogen.sh
    ./configure --prefix=$SWIG_DIR --disable-ccache
    make
    make -j8 install

    # Configure and build opensim-core.
    mkdir $OPENSIM_CORE_BUILD_DIR && cd $OPENSIM_CORE_BUILD_DIR
    ## Store CMake arguments in bash array.
    # https://stackoverflow.com/questions/1951506/add-a-new-element-to-an-array-without-specifying-the-index-in-bash
    OSIM_CMAKE_ARGS=($OPENSIM_CORE_SOURCE_DIR -DCMAKE_INSTALL_PREFIX=$OPENSIM_CORE_INSTALL_DIR -DCMAKE_BUILD_TYPE=$BTYPE)
    
    # The deployed binaries are used by the GUI, which requires the non-FHS
    # layout.
    OSIM_CMAKE_ARGS+=(-DOPENSIM_INSTALL_UNIX_FHS=OFF)
    
    # The minimum macOS/OSX version we support.
    OSIM_CMAKE_ARGS+=(-DCMAKE_OSX_DEPLOYMENT_TARGET=$OSX_TARGET)
    
    # Dependencies.
    OSIM_CMAKE_ARGS+=(-DOPENSIM_DEPENDENCIES_DIR=$OPENSIM_CORE_DEP_INSTALL_DIR -DWITH_BTK:BOOL=ON)
    
    # Bindings.
    OSIM_CMAKE_ARGS+=(-DBUILD_PYTHON_WRAPPING=ON -DBUILD_JAVA_WRAPPING=ON -DSWIG_EXECUTABLE=$SWIG_DIR/bin/swig)
    # On Mac, use system python instead of Homebrew python.
    OSIM_CMAKE_ARGS+=(-DPYTHON_EXECUTABLE=/usr/bin/python)
    
    # Doxygen.
    OSIM_CMAKE_ARGS+=(-DOPENSIM_DOXYGEN_USE_MATHJAX=ON -DOPENSIM_SIMBODY_DOXYGEN_LOCATION="https://simbody.github.io/simbody-3.6-doxygen/api/index.html")
    
    OSIM_CMAKE_ARGS+=(-DBUILD_TESTING=OFF)
    
    printf '%s\n' "${OSIM_CMAKE_ARGS[@]}"
    cmake "${OSIM_CMAKE_ARGS[@]}"
    
    make doxygen
    make -j$NPROC install

fi


if [[ $STAGE -eq 0 || $STAGE -eq 3 ]]
then

    # Obtain opensim-gui source code.
    git clone https://github.com/opensim-org/opensim-gui $OPENSIM_GUI_SOURCE_DIR
    cd $OPENSIM_GUI_SOURCE_DIR
    # TODO how to handle tags for these submodules?
    git submodule update --init --recursive -- \
        opensim-models \
        opensim-visualizer \
        Gui/opensim/threejs
    
    
    # Build opensim-gui.
    mkdir $OPENSIM_GUI_BUILD_DIR
    cd $OPENSIM_GUI_BUILD_DIR
    cmake $OPENSIM_GUI_SOURCE_DIR -DCMAKE_PREFIX_PATH=$OPENSIM_CORE_INSTALL_DIR -DAnt_EXECUTABLE="/Applications/NetBeans/NetBeans 8.2.app/Contents/Resources/NetBeans/extide/ant/bin/ant" -DANT_ARGS="-Dnbplatform.default.netbeans.dest.dir=/Applications/NetBeans/NetBeans 8.2.app/Contents/Resources/NetBeans;-Dnbplatform.default.harness.dir=/Applications/NetBeans/NetBeans 8.2.app/Contents/Resources/NetBeans/harness"
    make CopyOpenSimCore
    make PrepareInstaller

fi
