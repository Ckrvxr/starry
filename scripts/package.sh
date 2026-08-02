#!/bin/bash
# 编译并打包 Starry.app（macOS，Qt 6.11 homebrew 拆包环境）
set -euo pipefail
cd "$(dirname "$0")/.."

# Qt 6.11 homebrew 将 qtsvg 拆为独立包，macdeployqt 默认搜索不到 QtSvg.framework，
# 软链进 qtdeclarative 的 lib 目录让部署器可解析。
QTSVG=/opt/homebrew/opt/qtsvg/lib/QtSvg.framework
QTDECL=/opt/homebrew/opt/qtdeclarative/lib
if [ ! -e "$QTDECL/QtSvg.framework" ]; then
    ln -s "$QTSVG" "$QTDECL/QtSvg.framework"
fi

rm -rf build/Starry.app
cmake --build build -j "$(sysctl -n hw.ncpu)"

# -qmldir 必需：否则 QtQuick.Controls 等 QML 模块插件不会部署，启动即报
# "module QtQuick.Controls plugin qtquickcontrols2plugin not found"。
# 结尾的 codesign verification error 是 brew dylib 的已知噪音，忽略即可。
macdeployqt build/Starry.app -always-overwrite -qmldir=qml || true

# brew 的 dylib 复制后签名失效，统一 ad-hoc 深度重签。
codesign --force --deep --sign - build/Starry.app
codesign --verify --deep --strict build/Starry.app

echo "OK: build/Starry.app ($(du -sh build/Starry.app | cut -f1))"
