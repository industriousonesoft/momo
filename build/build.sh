#!/bin/bash

cd "`dirname $0`"

# 引数の処理

PROGRAM="$0"

_PACKAGES=" \
  windows \
  macos \
  raspberry-pi-os_armv6 \
  raspberry-pi-os_armv7 \
  raspberry-pi-os_armv8 \
  ubuntu-18.04_armv8_jetson_nano \
  ubuntu-18.04_armv8_jetson_xavier \
  ubuntu-18.04_x86_64 \
  ubuntu-20.04_x86_64 \
"

function show_help() {
  echo "$PROGRAM [--clean] [--package] [--no-cache] [--no-tty] [--no-mount] <package>"
  echo "<package>:"
  for package in $_PACKAGES; do
    echo "  - $package"
  done
}

PACKAGE=""
FLAG_CLEAN=0
FLAG_PACKAGE=0
DOCKER_BUILD_FLAGS=""
DOCKER_MOUNT_TYPE=mount

while [ $# -ne 0 ]; do
  case "$1" in
    "--clean" ) FLAG_CLEAN=1 ;;
    "--package" ) FLAG_PACKAGE=1 ;;
    "--no-cache" ) DOCKER_BUILD_FLAGS="$DOCKER_BUILD_FLAGS --no-cache" ;;
    "--no-tty" ) DOCKER_BUILD_FLAGS="$DOCKER_BUILD_FLAGS --progress=plain" ;;
    "--no-mount" ) DOCKER_MOUNT_TYPE=nomount ;;
    --* )
      show_help
      exit 1
      ;;
    * )
      if [ -n "$PACKAGE" ]; then
        show_help
        exit 1
      fi
      PACKAGE="$1"
      ;;
  esac
  shift 1
done

_FOUND=0
for package in $_PACKAGES; do
  if [ "$PACKAGE" = "$package" ]; then
    _FOUND=1
    break
  fi
done

if [ $_FOUND -eq 0 ]; then
  show_help
  exit 1
fi

echo "--clean: " $FLAG_CLEAN
echo "--package: " $FLAG_PACKAGE
echo "<package>: " $PACKAGE

set -ex

pushd ..
  MOMO_COMMIT="`git rev-parse HEAD`"
  MOMO_COMMIT_SHORT="`cat $MOMO_COMMIT | cut -b 1-8`"
popd

source ../VERSION

case "$PACKAGE" in
  "windows" )
    echo "Windows では build.bat を利用してください。"
    exit 1
    ;;
  "macos" )
    if [ $FLAG_CLEAN -eq 1 ]; then
      rm -rf ../_build/macos
      rm -rf macos/_source
      rm -rf macos/_build
      rm -rf macos/_install
      exit 0
    fi

    #安装配置momo在macOS下的依赖库
    ./macos/install_deps.sh

    #获取WebRTC的版本号
    source ./macos/_install/webrtc/VERSIONS

    #获取CPU数目
    if [ -z "$JOBS" ]; then
      JOBS=`sysctl -n hw.logicalcpu_max`
      if [ -z "$JOBS" ]; then
        JOBS=1
      fi
    fi

    #创建打包目录
    mkdir -p ../_build/$PACKAGE
    #切换到打包目录
    pushd ../_build/$PACKAGE
      #编译momo
      cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DMOMO_PACKAGE_NAME="macos" \
        -DMOMO_VERSION="$MOMO_VERSION" \
        -DMOMO_COMMIT="$MOMO_COMMIT" \
        -DWEBRTC_BUILD_VERSION="$WEBRTC_BUILD_VERSION" \
        -DWEBRTC_READABLE_VERSION="$WEBRTC_READABLE_VERSION" \
        -DWEBRTC_COMMIT="$WEBRTC_COMMIT" \
        ../..
      cmake --build . -j$JOBS
    #切回当前目录
    popd

    if [ $FLAG_PACKAGE -eq 1 ]; then
      #获得系统版本号
      MACOS_VERSION=`sw_vers -productVersion | cut -d '.' -f-2`
      
      pushd ..
        # パッケージのバイナリを作る
        rm -rf _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}
        rm -f _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}.tar.gz
        mkdir -p _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}
        cp    _build/macos/momo _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}/
        cp    LICENSE           _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}/
        cp    NOTICE            _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}/
        cp -r html              _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}/html
        pushd _package
          tar czf momo-${MOMO_VERSION}_macos-${MACOS_VERSION}.tar.gz momo-${MOMO_VERSION}_macos-${MACOS_VERSION}
        popd

        rm -rf _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}
        echo ""
        echo "パッケージが _package/momo-${MOMO_VERSION}_macos-${MACOS_VERSION}.tar.gz に生成されました。"
      popd
    fi

    ;;
  * )
    if [ $FLAG_CLEAN -eq 1 ]; then
      rm -rf ../_build/$PACKAGE
      IMAGES="`docker image ls -q momo/$PACKAGE`"
      if [ -n "$IMAGES" ]; then
        docker image rm $IMAGES
      fi
      docker builder prune -f --filter=label=jp.shiguredo.momo=$PACKAGE
      exit 0
    fi

    rm -rf $PACKAGE/script
    cp -r ../script $PACKAGE/script

    # 可能な限りキャッシュを利用する
    mkdir -p $PACKAGE/_cache/boost/
    if [ -e ../_cache/boost/ ]; then
      cp -r ../_cache/boost/* $PACKAGE/_cache/boost/
    fi

    DOCKER_BUILDKIT=1 docker build \
      -t momo/$PACKAGE:m$WEBRTC_BUILD_VERSION \
      $DOCKER_BUILD_FLAGS \
      --build-arg WEBRTC_BUILD_VERSION=$WEBRTC_BUILD_VERSION \
      --build-arg BOOST_VERSION=$BOOST_VERSION \
      --build-arg SDL2_VERSION=$SDL2_VERSION \
      --build-arg JSON_VERSION=$JSON_VERSION \
      --build-arg CLI11_VERSION=$CLI11_VERSION \
      --build-arg CMAKE_VERSION=$CMAKE_VERSION \
      --build-arg PACKAGE_NAME=$PACKAGE \
      $PACKAGE

    rm -rf $PACKAGE/_cache/boost/

    # キャッシュしたデータを取り出す
    set +e
    docker container create -it --name momo-$PACKAGE momo/$PACKAGE:m$WEBRTC_BUILD_VERSION
    docker container start momo-$PACKAGE
    mkdir -p ../_cache/boost/
    docker container cp momo-$PACKAGE:/root/_cache/boost/. ../_cache/boost/
    docker container stop momo-$PACKAGE
    docker container rm momo-$PACKAGE
    set -e

    rm -r $PACKAGE/script

    ../script/docker_run.sh `pwd` `pwd`/.. $DOCKER_MOUNT_TYPE $PACKAGE momo/$PACKAGE:m$WEBRTC_BUILD_VERSION $MOMO_COMMIT

    if [ $FLAG_PACKAGE -eq 1 ]; then
      pushd ..
        rm -rf _package/momo-${MOMO_VERSION}_${PACKAGE}
        rm -f _package/momo-${MOMO_VERSION}_${PACKAGE}.tar.gz
        mkdir -p _package/momo-${MOMO_VERSION}_${PACKAGE}
        cp    _build/${PACKAGE}/momo _package/momo-${MOMO_VERSION}_${PACKAGE}/
        cp    LICENSE                _package/momo-${MOMO_VERSION}_${PACKAGE}/
        cp    NOTICE                 _package/momo-${MOMO_VERSION}_${PACKAGE}/
        cp -r html                   _package/momo-${MOMO_VERSION}_${PACKAGE}/html
        pushd _package
          tar czf momo-${MOMO_VERSION}_${PACKAGE}.tar.gz momo-${MOMO_VERSION}_${PACKAGE}
        popd

        rm -rf _package/momo-${MOMO_VERSION}_${PACKAGE}
        echo ""
        echo "パッケージが _package/momo-${MOMO_VERSION}_${PACKAGE}.tar.gz に生成されました。"
      popd
    fi
    ;;
esac
