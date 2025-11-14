#!/bin/bash

# Configuration
PROJECT_DIR=$(git rev-parse --show-toplevel)
BUILD_TYPE="${1:-debug}"       # debug | release
BUILD_PLATFORM="${2:-linux}"    # linux | macos | windows
TARGET_DIR="$PROJECT_DIR/target/$BUILD_TYPE/$BUILD_PLATFORM"

MUSIC_NDP_DIR="$PROJECT_DIR/third-party/MusicNDP"
YAZI_DIR="$PROJECT_DIR/third-party/yazi"

# Platform mapping
case "$BUILD_PLATFORM" in
    "linux")
        KOTLIN_TARGET_DEBUG="linkDebugExecutableLinuxX64"
        KOTLIN_TARGET_RELEASE="linkReleaseExecutableLinuxX64"
        KOTLIN_OUT_DIR="linuxX64"
        RUST_TARGET=""
        BIN_EXT=""
        ;;
    "macos")
        KOTLIN_TARGET_DEBUG="linkDebugExecutableMacosArm64"
        KOTLIN_TARGET_RELEASE="linkReleaseExecutableMacosArm64"
        KOTLIN_OUT_DIR="macosArm64"
        RUST_TARGET=""
        BIN_EXT=""
        ;;
    "windows")
        KOTLIN_TARGET_DEBUG="linkDebugExecutableMingwX64"
        KOTLIN_TARGET_RELEASE="linkReleaseExecutableMingwX64"
        KOTLIN_OUT_DIR="mingwX64"
        RUST_TARGET="--target x86_64-pc-windows-gnu"
        BIN_EXT=".exe"
        ;;
    *)
        echo "Error: Unknown platform '$BUILD_PLATFORM' (linux|macos|windows)"
        exit 1
        ;;
esac

# Build type mapping
case "$BUILD_TYPE" in
    "debug")
        KOTLIN_BUILD_TYPE="$KOTLIN_TARGET_DEBUG"
        RUST_PROFILE="dev"
        ;;
    "release")
        KOTLIN_BUILD_TYPE="$KOTLIN_TARGET_RELEASE"
        RUST_PROFILE="release"
        ;;
    *)
        echo "Error: Unknown build type '$BUILD_TYPE' (debug|release)"
        exit 1
        ;;
esac

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

check_directory() {
    [ ! -d "$1" ] && error_exit "Directory not found: $1"
}

build_beat_search() {
    echo "Building beatsearch ($BUILD_TYPE-$BUILD_PLATFORM)..."
    check_directory "$MUSIC_NDP_DIR"

    cd "$MUSIC_NDP_DIR" || error_exit "Cannot enter MusicNDP"

    ./gradlew :youtube:$KOTLIN_BUILD_TYPE || exit 1

    SRC="$MUSIC_NDP_DIR/youtube/build/bin/$KOTLIN_OUT_DIR/${BUILD_TYPE}Executable/youtube.kexe"
    cp "$SRC" "$TARGET_DIR/bin/beatsearch$BIN_EXT"
}

build_beat_tui() {
    echo "Building yazi ($BUILD_TYPE-$BUILD_PLATFORM)..."
    check_directory "$YAZI_DIR"

    cd "$YAZI_DIR" || error_exit "Cannot enter yazi"

    if [ "$BUILD_TYPE" = "release" ]; then
        cargo build --bin yazi --profile release $RUST_TARGET --manifest-path ./yazi-fm/Cargo.toml
        cp "$YAZI_DIR/target/$RUST_PROFILE/yazi$BIN_EXT" "$TARGET_DIR/bin/beattui$BIN_EXT"
    else
        cargo build --bin yazi --profile dev $RUST_TARGET --manifest-path ./yazi-fm/Cargo.toml
        cp "$YAZI_DIR/target/$RUST_PROFILE/yazi$BIN_EXT" "$TARGET_DIR/bin/beattui$BIN_EXT"
    fi
}

build_beat_server() {
    echo "Building beatserver ($BUILD_TYPE-$BUILD_PLATFORM)..."
    cd "$PROJECT_DIR" || error_exit "Cannot enter project"

    dart compile exe "$PROJECT_DIR/src/beatserver.dart" \
        -o "$TARGET_DIR/bin/beatserver$BIN_EXT"
}

copy_scripts() {
    echo "Copying scripts..."
    cp "$PROJECT_DIR/src/beatcmd.sh" "$TARGET_DIR/bin/beatcmd"
    cp "$PROJECT_DIR/src/beatshell.sh" "$TARGET_DIR/beatshell"
    cp "$PROJECT_DIR/src/loading.sh" "$TARGET_DIR/bin/loading"
    chmod +x "$TARGET_DIR/bin/"* "$TARGET_DIR/beatshell"
}

main() {
    echo "Building ($BUILD_TYPE-$BUILD_PLATFORM) in $PROJECT_DIR"

    mkdir -p "$TARGET_DIR/bin"

    build_beat_search
    build_beat_tui
    build_beat_server
    copy_scripts

    echo "Build done!"
    ls -la "$TARGET_DIR/bin"
}

main
