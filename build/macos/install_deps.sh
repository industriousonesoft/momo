#!/bin/bash

cd "`dirname $0`"

#-e: 告诉bash如果任何语句的执行结果不是true则应该退出
#-x: 指令执行后先显示该指令及相关参数，可作为日志输出，避免频繁调用echo
set -ex

SOURCE_DIR="`pwd`/_source"
BUILD_DIR="`pwd`/_build"
INSTALL_DIR="`pwd`/_install"
CACHE_DIR="`pwd`/../../_cache"

mkdir -p $SOURCE_DIR
mkdir -p $BUILD_DIR
mkdir -p $INSTALL_DIR
mkdir -p $CACHE_DIR

#在当前shell中执行VERSION中的shell命令：一些依赖库的版本号变量
source ../../VERSION

#获取CPU数目
if [ -z "$JOBS" ]; then
  JOBS=`sysctl -n hw.logicalcpu_max`
  if [ -z "$JOBS" ]; then
    JOBS=1
  fi
fi

#判断是否需要下载或者更新CLI11
# CLI11: CLI11 is a command line parser for C++11 a
CLI11_VERSION_FILE="$INSTALL_DIR/cli11.version"
CLI11_CHANGED=0
if [ ! -e $CLI11_VERSION_FILE -o "$CLI11_VERSION" != "`cat $CLI11_VERSION_FILE`" ]; then
  CLI11_CHANGED=1
fi

if [ $CLI11_CHANGED -eq 1 -o ! -e $INSTALL_DIR/CLI11/include/CLI/Version.hpp ]; then
  pushd $INSTALL_DIR
    rm -rf CLI11
    git clone --branch v$CLI11_VERSION --depth 1 https://github.com/CLIUtils/CLI11.git
  popd
fi
echo $CLI11_VERSION > $CLI11_VERSION_FILE

#判断是否需要下载或更新JSON库
# nlohmann/json
JSON_VERSION_FILE="$INSTALL_DIR/json.version"
JSON_CHANGED=0
if [ ! -e $JSON_VERSION_FILE -o "$JSON_VERSION" != "`cat $JSON_VERSION_FILE`" ]; then
  JSON_CHANGED=1
fi

if [ $JSON_CHANGED -eq 1 -o ! -e $INSTALL_DIR/json/include/nlohmann/json.hpp ]; then
  pushd $INSTALL_DIR
    rm -rf json
    git clone --branch v$JSON_VERSION --depth 1 https://github.com/nlohmann/json.git
  popd
fi
echo $JSON_VERSION > $JSON_VERSION_FILE

#判断是否需要下载或者更新WebRTC库
# WebRTC
WEBRTC_VERSION_FILE="$INSTALL_DIR/webrtc.version"
WEBRTC_CHANGED=0
if [ ! -e $WEBRTC_VERSION_FILE -o "$WEBRTC_BUILD_VERSION" != "`cat $WEBRTC_VERSION_FILE`" ]; then
  WEBRTC_CHANGED=1
fi

if [ $WEBRTC_CHANGED -eq 1 -o ! -e $INSTALL_DIR/webrtc/lib/libwebrtc.a ]; then
  rm -rf $INSTALL_DIR/webrtc
  ../../script/get_webrtc.sh $WEBRTC_BUILD_VERSION macos $INSTALL_DIR $SOURCE_DIR
fi
echo $WEBRTC_BUILD_VERSION > $WEBRTC_VERSION_FILE

#判断是否需要下载LLVM编译器
# LLVM
if [ ! -e $INSTALL_DIR/llvm/clang/bin/clang++ ]; then
  rm -rf $INSTALL_DIR/llvm
  ../../script/get_llvm.sh $INSTALL_DIR/webrtc $INSTALL_DIR
fi

#判断是否需要更新Boost组件
# Boost
BOOST_VERSION_FILE="$INSTALL_DIR/boost.version"
BOOST_CHANGED=0
if [ ! -e $BOOST_VERSION_FILE -o "$BOOST_VERSION" != "`cat $BOOST_VERSION_FILE`" ]; then
  BOOST_CHANGED=1
fi

if [ $BOOST_CHANGED -eq 1 -o ! -e $INSTALL_DIR/boost/lib/libboost_filesystem.a ]; then
  rm -rf $SOURCE_DIR/boost
  rm -rf $BUILD_DIR/boost
  rm -rf $INSTALL_DIR/boost
  ../../script/setup_boost.sh $BOOST_VERSION $SOURCE_DIR/boost $CACHE_DIR/boost
  #切换到boost源目录
  pushd $SOURCE_DIR/boost/source
    echo "using clang : : $INSTALL_DIR/llvm/clang/bin/clang++ : ;" > project-config.jam
    SYSROOT="`xcrun --sdk macosx --show-sdk-path`"
    #使用b2命令编译boost库
    ./b2 \
      cflags=" \
        --sysroot=$SYSROOT \
      " \
      cxxflags=" \
        -isystem $INSTALL_DIR/llvm/libcxx/include \
        -nostdinc++ \
        --sysroot=$SYSROOT \
      " \
      toolset=clang \
      visibility=hidden \
      link=static \
      variant=release \
      install \
      -j$JOBS \
      --build-dir=$BUILD_DIR/boost \
      --prefix=$INSTALL_DIR/boost \
      --ignore-site-config \
      --with-filesystem
  #返回切换前的目录：类似cd -
  popd
fi
echo $BOOST_VERSION > $BOOST_VERSION_FILE

#判断是否需要下载或者更新SDL2库
# SDL2
SDL2_VERSION_FILE="$INSTALL_DIR/sdl2.version"
SDL2_CHANGED=0
if [ ! -e $SDL2_VERSION_FILE -o "$SDL2_VERSION" != "`cat $SDL2_VERSION_FILE`" ]; then
  SDL2_CHANGED=1
fi

if [ $SDL2_CHANGED -eq 1 -o ! -e $INSTALL_DIR/SDL2/lib/libSDL2.a ]; then
  rm -rf $SOURCE_DIR/SDL2
  rm -rf $BUILD_DIR/SDL2
  rm -rf $INSTALL_DIR/SDL2
  mkdir -p $SOURCE_DIR/SDL2
  mkdir -p $BUILD_DIR/SDL2
  ../../script/setup_sdl2.sh $SDL2_VERSION $SOURCE_DIR/SDL2
  #切换到SDL2目录下
  pushd $BUILD_DIR/SDL2
    # SDL2 の CMakeLists.txt は Metal をサポートしてくれてないので、configure でビルドする
    # ref: https://bugzilla.libsdl.org/show_bug.cgi?id=4617
    #编译macOS平台下的SDL库
    SYSROOT="`xcrun --sdk macosx --show-sdk-path`"
    CC="$INSTALL_DIR/llvm/clang/bin/clang --sysroot=$SYSROOT" \
      CXX="$INSTALL_DIR/llvm/clang/bin/clang++ --sysroot=$SYSROOT -nostdinc++" \
      $SOURCE_DIR/SDL2/source/configure --disable-shared --prefix=$INSTALL_DIR/SDL2
    make -j$JOBS
    make install
  #返回切换前的目录
  popd
fi
echo $SDL2_VERSION > $SDL2_VERSION_FILE
