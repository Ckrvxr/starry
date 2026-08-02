#!/bin/bash
# 开发循环：增量编译 → 重启本地实例（不打包）
# 用法: ./scripts/dev.sh [--rebuild]   # --rebuild 强制全量重建
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" = "--rebuild" ]; then
    rm -rf build
    cmake -S . -B build
fi

cmake --build build -j "$(sysctl -n hw.ncpu)"

# 清除 macdeployqt 打包残留：app 内 Qt 框架、插件和 qt.conf 会让开发模式
# 双 Qt 冲突或找不到 cocoa 平台插件，直接依赖 brew 的 Qt 运行。
rm -rf build/Starry.app/Contents/Frameworks build/Starry.app/Contents/PlugIns
rm -f build/Starry.app/Contents/Resources/qt.conf

# 杀掉旧实例（当前屏幕上运行中的 Starry），再启动新编译的二进制
pkill -f 'Starry.app/Contents/MacOS/Starry' 2>/dev/null || true
sleep 0.5
./build/Starry.app/Contents/MacOS/Starry &
