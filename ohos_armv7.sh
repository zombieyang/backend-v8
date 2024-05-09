#!/bin/bash

VERSION=$1
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE="$( cd "$( dirname "$0" )"/.. && pwd )"

if [ "$VERSION" == "10.6.194" ]; then 
    sudo apt-get install -y \
        pkg-config \
        git \
        subversion \
        curl \
        wget \
        build-essential \
        python3 \
        xz-utils \
        zip
        
    pip install virtualenv
else
    sudo apt-get install -y \
        pkg-config \
        git \
        subversion \
        curl \
        wget \
        build-essential \
        python \
        xz-utils \
        zip
fi

sudo apt-get install -y ninja-build

cd ~
echo "=====[ Getting Depot Tools ]====="	
git clone -q https://chromium.googlesource.com/chromium/tools/depot_tools.git
export DEPOT_TOOLS_UPDATE=0
export PATH=$(pwd)/depot_tools:$PATH
gclient


mkdir v8
cd v8

echo "=====[ Fetching V8 ]====="
fetch v8
echo "target_os = ['android']" >> .gclient
cd ~/v8/v8
git checkout refs/tags/$VERSION

gclient sync -D


# echo "=====[ Patching V8 ]====="
# git apply --cached $GITHUB_WORKSPACE/patches/builtins-puerts.patches
# git checkout -- .

echo "=====[ add ArrayBuffer_New_Without_Stl ]====="
node $GITHUB_WORKSPACE/node-script/add_arraybuffer_new_without_stl.js .

if [ "$VERSION" == "9.4.146.24" ]; then 
  echo "=====[ patch jinja for python3.10+ ]====="
  cd third_party/jinja2
  node $GITHUB_WORKSPACE/node-script/do-gitpatch.js -p $GITHUB_WORKSPACE/patches/jinja_v9.4.146.24.patch
  cd ../..
fi

echo "=====[ patch for ohos ]====="
node $GITHUB_WORKSPACE/node-script/do-gitpatch.js -p $GITHUB_WORKSPACE/patches/ohos_v8_v$VERSION.patch
cd build
node $GITHUB_WORKSPACE/node-script/do-gitpatch.js -p $GITHUB_WORKSPACE/patches/ohos_build_v$VERSION.patch
cd ../third_party/zlib
node $GITHUB_WORKSPACE/node-script/do-gitpatch.js -p $GITHUB_WORKSPACE/patches/ohos_zlib_v$VERSION.patch
cd ../..

echo "=====[ Building V8 ]====="
gn gen --args="target_os=\"ohos\" target_cpu=\"arm\" is_debug = false v8_enable_i18n_support= false v8_target_cpu = \"arm\" use_goma = false v8_use_external_startup_data = false v8_static_library = true strip_debug_info = false symbol_level=1 use_custom_libcxx=false use_custom_libcxx_for_host=true v8_enable_pointer_compression=false use_musl=true" out.gn/arm.release
ninja -C out.gn/arm.release -t clean
ninja -v -C out.gn/arm.release wee8

mkdir -p output/v8/Lib/OHOS/armeabi-v7a
cp out.gn/arm.release/obj/libwee8.a output/v8/Lib/OHOS/armeabi-v7a/
mkdir -p output/v8/Inc/Blob/OHOS/armv7a
