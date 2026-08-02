#include "macoswindow.h"

#include <QGuiApplication>
#include <QQuickWindow>

#ifdef Q_OS_MACOS
#import <Cocoa/Cocoa.h>

namespace MacWindowStyler {

void apply(QQuickWindow *window)
{
    if (!window)
        return;

    // macOS 上 QWindow::winId() 对应内容 NSView，通过 view.window 获取宿主 NSWindow。
    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nativeWindow = hostView.window;
    if (!nativeWindow)
        return;

    // 完全交给 NSWindow：系统负责圆角、阴影、标题栏拖动和红绿灯按钮。
    NSWindowStyleMask styleMask = nativeWindow.styleMask;
    styleMask &= ~NSWindowStyleMaskBorderless;
    styleMask |= NSWindowStyleMaskTitled
              | NSWindowStyleMaskFullSizeContentView
              | NSWindowStyleMaskResizable
              | NSWindowStyleMaskClosable
              | NSWindowStyleMaskMiniaturizable;
    nativeWindow.styleMask = styleMask;
    nativeWindow.titlebarAppearsTransparent = NO;
    nativeWindow.titleVisibility = NSWindowTitleHidden;
    nativeWindow.movable = YES;
    nativeWindow.opaque = YES;
    nativeWindow.backgroundColor = [NSColor colorWithCalibratedWhite:0.043 alpha:1.0];
    nativeWindow.hasShadow = YES;

    // 使用系统红绿灯，不再由 QML 模拟。
    const NSWindowButton buttons[] = { NSWindowCloseButton,
                                       NSWindowMiniaturizeButton,
                                       NSWindowZoomButton };
    for (NSWindowButton button : buttons) {
        NSButton *nativeButton = [nativeWindow standardWindowButton:button];
        [nativeButton setHidden:NO];
        [nativeButton setEnabled:YES];
        [nativeButton setAlphaValue:1.0];
    }
}

}
#else
namespace MacWindowStyler {
void apply(QQuickWindow *) {}
}
#endif
