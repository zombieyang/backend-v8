VERSION=$1
[ -z "$GITHUB_WORKSPACE" ] && GITHUB_WORKSPACE="$( cd "$( dirname "$0" )"/.. && pwd )"

apt-get update
apt-get install -y \
    lsb-core \
    lib32stdc++6 \
    git \
    curl 	\
    lbzip2 \
    pkg-config \
    git \
    subversion \
    curl \
    wget \
    build-essential \
    python \
    python3 \
    xz-utils \
    libatomic1 \
    zip 
   
rm -rf /var/lib/apt/lists/*

cd ~
wget https://nodejs.org/dist/latest-v14.x/node-v14.21.3-linux-x64.tar.gz
tar xzf node-v14.21.3-linux-x64.tar.gz
export PATH=$(pwd)/node-v14.21.3-linux-x64x/bin/:$PATH

echo "=====[ Getting Depot Tools ]====="	
git clone -q https://chromium.googlesource.com/chromium/tools/depot_tools.git
cd depot_tools
git reset --hard 8d16d4a
cd ..
export DEPOT_TOOLS_UPDATE=0
export PATH=$(pwd)/depot_tools:$PATH
gclient


mkdir v8
cd v8

echo "=====[ Fetching V8 ]====="
fetch v8
echo "target_os = ['android']" >> .gclient
cd ~/v8/v8
./build/install-build-deps-android.sh
git checkout refs/tags/$VERSION

echo "=====[ fix DEPS ]===="
node -e "const fs = require('fs'); fs.writeFileSync('./DEPS', fs.readFileSync('./DEPS', 'utf-8').replace(\"Var('chromium_url') + '/external/github.com/kennethreitz/requests.git'\", \"'https://github.com/kennethreitz/requests'\"));"

gclient sync


# echo "=====[ Patching V8 ]====="
# git apply --cached $GITHUB_WORKSPACE/patches/builtins-puerts.patches
# git checkout -- .

echo "=====[ add ArrayBuffer_New_Without_Stl ]====="
node $GITHUB_WORKSPACE/node-script/add_arraybuffer_new_without_stl.js .

echo "=====[ Building V8 ]====="
python ./tools/dev/v8gen.py arm.release -vv -- '
target_os = "android"
target_cpu = "arm"
is_debug = false
v8_enable_i18n_support= false
v8_target_cpu = "arm"
v8_static_library = true
strip_debug_info = false
v8_use_snapshot = true
v8_use_external_startup_data = true
is_component_build=false
symbol_level=1
'
ninja -C out.gn/arm.release -t clean
ninja -C out.gn/arm.release wee8
third_party/android_ndk/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/arm-linux-androideabi/bin/strip -g -S -d --strip-debug --verbose out.gn/arm.release/obj/libwee8.a

node $GITHUB_WORKSPACE/node-script/genBlobHeader.js "android armv7" out.gn/arm.release/snapshot_blob.bin

mkdir -p output/v8/Lib/Android/armeabi-v7a
cp out.gn/arm.release/obj/libwee8.a output/v8/Lib/Android/armeabi-v7a/
mkdir -p output/v8/Inc/Blob/Android/armv7a
cp SnapshotBlob.h output/v8/Inc/Blob/Android/armv7a/
