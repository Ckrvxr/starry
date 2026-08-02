# Starry

Starry 是一个基于 **Qt 6 + libmpv** 的跨平台 Emby 桌面播放器。界面采用深色、内容优先的媒体库布局，支持 macOS、Windows 和 Linux。

## 当前功能

- Emby 服务器登录与本地会话恢复
- 媒体库、电影、剧集和搜索
- 海报墙、详情页、继续播放进度
- libmpv 原生内嵌渲染和硬件解码
- 播放/暂停、精准跳转、音量、音轨和字幕切换
- 全屏播放、键盘快捷键、Emby 播放状态回传
- macOS App Bundle 与 Windows GUI 可执行文件配置
- 全平台 18px 圆角窗口与自绘标题栏按钮；macOS 使用 Cocoa 圆角/阴影，Windows/Linux 使用 Qt 原生窗口裁剪

## 开发依赖

- CMake 3.24+
- Qt 6.5+：Core、Gui、Quick、Qml、Network、OpenGL
- libmpv 0.35+
- pkg-config

### macOS

```bash
brew install cmake qt mpv pkg-config
cmake -S . -B build -DCMAKE_PREFIX_PATH="$(brew --prefix qt)"
cmake --build build -j
open build/Starry.app
```

Homebrew 的 mpv 默认提供 `libmpv` 和 `mpv.pc`。发布应用时，还需要使用 `macdeployqt` 并将 libmpv 及其动态依赖复制到 App Bundle。

macOS 版本会保留系统窗口容器，因此在 macOS 26（Tahoe）上可以使用系统级圆角和阴影；标题文字与关闭、最小化、最大化按钮由 Starry 自己绘制。

### Ubuntu / Debian

```bash
sudo apt install cmake ninja-build qt6-base-dev qt6-declarative-dev libmpv-dev pkg-config
cmake -S . -B build -G Ninja
cmake --build build
./build/Starry
```

### Windows

建议使用 vcpkg 安装 Qt 6 与 mpv，并确保 `pkg-config` 能找到 `mpv.pc`：

```powershell
vcpkg install qtdeclarative:x64-windows mpv:x64-windows
cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake
cmake --build build --config Release
```

## 快捷键

- `Space`：播放/暂停
- `←` / `→`：后退/前进 10 秒
- 双击视频：切换全屏
- `Esc`：退出全屏或关闭播放器

## 架构

- `src/embyclient.*`：Emby HTTP API、认证、媒体模型、图片和播放进度
- `src/mpvplayer.*`：libmpv Render API 与 Qt Quick OpenGL FBO 桥接
- `qml/`：登录、媒体库、详情和播放器 UI

当前版本优先使用 Direct Play，让 libmpv 处理容器和编解码。后续适合补充 Emby PlaybackInfo 协商、服务端转码、剧集分季、下载缓存和设置中心。

## 许可证

Starry 使用 GNU Affero General Public License v3.0 或更高版本，详见 [LICENSE](LICENSE)。
