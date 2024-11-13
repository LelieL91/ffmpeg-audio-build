#!/usr/bin/env bash

set -eu

cd $(dirname "$0")
BASE_DIR=$(pwd)

source common.sh

[ -e "$FFMPEG_TARBALL" ] || curl -s -L -O "$FFMPEG_TARBALL_URL"
[ -e "SDL2-$SDL2_VERSION.tar.gz" ] || curl -s -L -O "$SDL2_LIN_URL"

: ${ARCH?}

OUTPUT_DIR="artifacts/ffmpeg-$FFMPEG_VERSION-audio-$ARCH-linux-gnu"

BUILD_DIR=$(mktemp -d -p $(pwd) build.XXXXXXXX)
trap 'rm -rf $BUILD_DIR' EXIT

case $ARCH in
    x86_64)
        SDL2_CONFIGURE_FLAGS+=(
          --host=
        )
        ;;
    i686)
        FFMPEG_CONFIGURE_FLAGS+=(--cc='gcc -m32')
        ;;
    arm64)
        SDL2_CONFIGURE_FLAGS+=(
            --build=x86_64-pc-linux-gnu
            --host=aarch64-linux-gnu
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
        )
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=aarch64-linux-gnu-
            --target-os=linux
            --arch=aarch64
        )
        ;;
    arm*)
        SDL2_CONFIGURE_FLAGS+=(
            --cross-prefix=arm-linux-gnueabihf-
        )
        FFMPEG_CONFIGURE_FLAGS+=(
            --enable-cross-compile
            --cross-prefix=arm-linux-gnueabihf-
            --target-os=linux
            --arch=arm
        )
        case $ARCH in
            armv7-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv7-a
                )
                ;;
            armv8-a)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=armv8-a
                )
                ;;
            armhf-rpi2)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a7
                    --extra-cflags='-fPIC -mcpu=cortex-a7 -mfloat-abi=hard -mfpu=neon-vfpv4 -mvectorize-with-neon-quad'
                )
                ;;
            armhf-rpi3)
                FFMPEG_CONFIGURE_FLAGS+=(
                    --cpu=cortex-a53
                    --extra-cflags='-fPIC -mcpu=cortex-a53 -mfloat-abi=hard -mfpu=neon-fp-armv8 -mvectorize-with-neon-quad'
                )
                ;;
        esac
        ;;
    *)
        echo "Unknown architecture: $ARCH"
        exit 1
        ;;
esac

cd "$BUILD_DIR"
tar -xzf "$BASE_DIR/SDL2-$SDL2_VERSION.tar.gz"

cd "SDL2-$SDL2_VERSION"
mkdir -p "$BUILD_DIR/sdl2"
SDL2_CONFIGURE_FLAGS+=(--prefix="$BUILD_DIR/sdl2")
./configure "${SDL2_CONFIGURE_FLAGS[@]}"
make -j$(nproc)
make install

cd $BUILD_DIR
tar --strip-components=1 -xf "$BASE_DIR/$FFMPEG_TARBALL"

FFMPEG_CONFIGURE_FLAGS+=(--prefix="$BASE_DIR/$OUTPUT_DIR")
FFMPEG_CONFIGURE_FLAGS+=(--extra-cflags="-I$BUILD_DIR/sdl2/include")
FFMPEG_CONFIGURE_FLAGS+=(--extra-ldflags="-L$BUILD_DIR/sdl2/lib -lSDL2")

./configure "${FFMPEG_CONFIGURE_FLAGS[@]}" || (cat 'ffbuild/config.log' && exit 1)

make -j$(nproc)
make install

chown $(stat -c '%u:%g' "$BASE_DIR") -R "$BASE_DIR/$OUTPUT_DIR"
