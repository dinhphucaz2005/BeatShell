#!/bin/bash

# Configuration
PROJECT_DIR=$(git rev-parse --show-toplevel)
BUILD_TYPE="${1:-debug}"
TARGET_DIR="$PROJECT_DIR/target/$BUILD_TYPE"
MUSIC_NDP_DIR="$PROJECT_DIR/third-party/MusicNDP"
YAZI_DIR="$PROJECT_DIR/third-party/yazi"

# Build configuration
case "$BUILD_TYPE" in
    "debug")
        KOTLIN_BUILD_TYPE="debugExecutableLinuxX64"
        RUST_PROFILE="dev"
        DART_FLAGS="compile exe"
        ;;
    "release")
        KOTLIN_BUILD_TYPE="linkReleaseExecutableLinuxX64"
        RUST_PROFILE="release"
        DART_FLAGS="compile exe --no-native"
        ;;
    *)
        echo "Error: Unknown build type '$BUILD_TYPE'. Use 'debug' or 'release'"
        exit 1
        ;;
esac

# Functions
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

check_directory() {
    if [ ! -d "$1" ]; then
        error_exit "Directory not found: $1"
    fi
}

build_beat_search() {
    echo "Building youtube.kexe ($BUILD_TYPE)..."
    check_directory "$MUSIC_NDP_DIR"
    
    cd "$MUSIC_NDP_DIR" || error_exit "Cannot enter MusicNDP directory"
    
    if [ "$BUILD_TYPE" = "release" ]; then
        ./gradlew :youtube:linkReleaseExecutableLinuxX64
        cp "$MUSIC_NDP_DIR/youtube/build/bin/linuxX64/releaseExecutable/youtube.kexe" \
           "$TARGET_DIR/bin/beatsearch.kexe"
    else
        ./gradlew :youtube:linkDebugExecutableLinuxX64
        cp "$MUSIC_NDP_DIR/youtube/build/bin/linuxX64/debugExecutable/youtube.kexe" \
           "$TARGET_DIR/bin/beatsearch.kexe"
    fi
}

build_beat_tui() {
    echo "Building yazi ($BUILD_TYPE)..."
    check_directory "$YAZI_DIR"
    
    cd "$YAZI_DIR" || error_exit "Cannot enter yazi directory"
    
    if [ "$BUILD_TYPE" = "release" ]; then
        cargo build --bin yazi --profile release --manifest-path ./yazi-fm/Cargo.toml
        cp "$YAZI_DIR/target/release/yazi" "$TARGET_DIR/bin/beattui"
    else
        cargo build --bin yazi --profile dev --manifest-path ./yazi-fm/Cargo.toml
        cp "$YAZI_DIR/target/debug/yazi" "$TARGET_DIR/bin/beattui"
    fi
}

build_beat_server() {
    echo "Building beatserver ($BUILD_TYPE)..."
    check_directory "$PROJECT_DIR"
    
    cd "$PROJECT_DIR" || error_exit "Cannot enter project directory"
    dart compile exe "$PROJECT_DIR/src/beatserver.dart" -o "$TARGET_DIR/bin/beatserver"
}

copy_scripts() {
    echo "Copying scripts..."
    cp "$PROJECT_DIR/src/beatcmd.sh" "$TARGET_DIR/bin/beatcmd"
    cp "$PROJECT_DIR/src/beatshell.sh" "$TARGET_DIR/beatshell"
    chmod +x "$TARGET_DIR/bin/beatcmd" "$TARGET_DIR/beatshell"
}

# Main execution
main() {
    echo "Building project in $PROJECT_DIR (Mode: $BUILD_TYPE)"
    
    # Create directories
    mkdir -p "$TARGET_DIR/bin"
    
    # Build components
    build_beat_search
    build_beat_tui
    build_beat_server
    copy_scripts
    
    echo "Build completed successfully!"
    echo "Output directory: $TARGET_DIR"
    echo "Available binaries:"
    ls -la "$TARGET_DIR/bin/"
}

# Run main function
main