#define GL_SILENCE_DEPRECATION

#include "macoswindow.h"

#include <QGuiApplication>
#include <QOpenGLContext>
#include <QtGui/qopenglcontext_platform.h>
#include <QPointer>
#include <QQuickGraphicsDevice>
#include <QQuickWindow>

#ifdef Q_OS_MACOS
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

namespace {
char fullscreenExitObserverKey;
char edrContextKey;

NSColorSpace *extendedSrgbColorSpace()
{
    CGColorSpaceRef cgColorSpace = CGColorSpaceCreateWithName(
        kCGColorSpaceExtendedSRGB);
    if (!cgColorSpace)
        return nil;
    NSColorSpace *colorSpace = [[[NSColorSpace alloc]
        initWithCGColorSpace:cgColorSpace] autorelease];
    CGColorSpaceRelease(cgColorSpace);
    return colorSpace;
}

NSOpenGLContext *edrContext(QQuickWindow *window)
{
    if (!window)
        return nil;
    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    return (NSOpenGLContext *)objc_getAssociatedObject(hostView.window, &edrContextKey);
}

CALayer *contentLayer(QQuickWindow *window)
{
    if (!window)
        return nil;
    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    return hostView.layer ?: hostView.window.contentView.layer;
}
}

namespace MacWindowStyler {

bool prepareEdrRendering(QQuickWindow *window)
{
    if (!window)
        return false;

    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nativeWindow = hostView.window;
    if (!nativeWindow)
        return false;
    if (edrContext(window))
        return true;

    // 与 mpv/IINA 的 macOS HDR 输出保持一致：最终 drawable 必须是
    // 64-bit half-float，而不仅仅是中间 FBO 使用 RGBA16F。
    const NSOpenGLPixelFormatAttribute attributes[] = {
        NSOpenGLPFAOpenGLProfile,
        NSOpenGLProfileVersion4_1Core,
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAColorSize,
        static_cast<NSOpenGLPixelFormatAttribute>(64),
        NSOpenGLPFAColorFloat,
        NSOpenGLPFAAllowOfflineRenderers,
        static_cast<NSOpenGLPixelFormatAttribute>(0)
    };

    NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc]
        initWithAttributes:attributes];
    if (!pixelFormat)
        return false;
    NSOpenGLContext *nativeContext = [[NSOpenGLContext alloc]
        initWithFormat:pixelFormat shareContext:nil];
    [pixelFormat release];
    if (!nativeContext)
        return false;

    GLint swapInterval = 1;
    [nativeContext setValues:&swapInterval
                forParameter:NSOpenGLContextParameterSwapInterval];

    QOpenGLContext *qtContext = QNativeInterface::QCocoaGLContext::fromNative(nativeContext);
    if (!qtContext) {
        [nativeContext release];
        return false;
    }
    qtContext->setParent(window);
    window->setGraphicsDevice(QQuickGraphicsDevice::fromOpenGLContext(qtContext));
    objc_setAssociatedObject(nativeWindow, &edrContextKey, nativeContext,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    // Qt Quick 的颜色值默认是 sRGB；即使在 SDR 首页也保持同一个扩展 sRGB
    // 标记，避免浮点 drawable 被系统按显示器原生 P3 直接解释而整体发灰。
    nativeWindow.colorSpace = extendedSrgbColorSpace();
    [nativeContext release];
    return true;
}

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

    // macOS 会在原生全屏切换过程中改写 NSWindow 的 styleMask。退出全屏后
    // 等 Qt 完成窗口状态同步，再重新应用普通窗口的标题栏、边框和阴影样式。
    if (!objc_getAssociatedObject(nativeWindow, &fullscreenExitObserverKey)) {
        const QPointer<QQuickWindow> guardedWindow(window);
        id observer = [[NSNotificationCenter defaultCenter]
            addObserverForName:NSWindowDidExitFullScreenNotification
                        object:nativeWindow
                         queue:NSOperationQueue.mainQueue
                    usingBlock:^(NSNotification *) {
                        if (!guardedWindow)
                            return;
                        QMetaObject::invokeMethod(guardedWindow.data(), [guardedWindow] {
                            if (guardedWindow)
                                MacWindowStyler::apply(guardedWindow.data());
                        }, Qt::QueuedConnection);
                    }];
        objc_setAssociatedObject(nativeWindow, &fullscreenExitObserverKey, observer,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

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

void setEdrEnabled(QQuickWindow *window, bool enabled)
{
    CALayer *layer = contentLayer(window);
    if (!layer)
        return;

    NSScreen *screen = reinterpret_cast<NSView *>(window->winId()).window.screen
        ?: NSScreen.mainScreen;
    const CGFloat availableHeadroom = screen
        ? qMax(1.0, screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
        : 1.0;

    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nativeWindow = hostView.window;

    // NSOpenGL drawable 与窗口色彩空间必须和 mpv 的 target-trc/target-prim
    // 一致。Extended sRGB 与 QML 的默认颜色空间相同，同时允许超过 SDR 白。
    if ([hostView respondsToSelector:@selector(wantsExtendedDynamicRangeOpenGLSurface)])
        [hostView setValue:@(enabled) forKey:@"wantsExtendedDynamicRangeOpenGLSurface"];
    nativeWindow.colorSpace = extendedSrgbColorSpace();

    layer.contentsFormat = enabled ? kCAContentsFormatRGBA16Float
                                   : kCAContentsFormatRGBA8Uint;
    if (@available(macOS 26.0, *)) {
        layer.contentsHeadroom = enabled ? availableHeadroom : 1.0;
        layer.preferredDynamicRange = enabled ? CADynamicRangeHigh
                                              : CADynamicRangeStandard;
    } else if ([layer respondsToSelector:@selector(wantsExtendedDynamicRangeContent)]) {
        [layer setValue:@(enabled) forKey:@"wantsExtendedDynamicRangeContent"];
    }
    if (@available(macOS 15.0, *))
        layer.toneMapMode = CAToneMapModeAutomatic;
    [layer setNeedsDisplay];
}

QVariantMap displayHdrInfo(QQuickWindow *window)
{
    if (!window)
        return {{QStringLiteral("available"), false}};

    NSView *hostView = reinterpret_cast<NSView *>(window->winId());
    NSWindow *nativeWindow = hostView.window;
    NSScreen *screen = nativeWindow.screen ?: NSScreen.mainScreen;
    if (!screen)
        return {{QStringLiteral("available"), false}};

    const double current = screen.maximumExtendedDynamicRangeColorComponentValue;
    const double potential = screen.maximumPotentialExtendedDynamicRangeColorComponentValue;
    const double reference = screen.maximumReferenceExtendedDynamicRangeColorComponentValue;
    bool layerEnabled = false;
    double contentHeadroom = 0.0;
    bool floatSurface = false;
    int colorBits = 0;
    NSOpenGLContext *nativeContext = edrContext(window);
    if (nativeContext) {
        [nativeContext.pixelFormat getValues:&colorBits
                                forAttribute:NSOpenGLPFAColorSize
                            forVirtualScreen:0];
        GLint colorFloat = 0;
        [nativeContext.pixelFormat getValues:&colorFloat
                                forAttribute:NSOpenGLPFAColorFloat
                            forVirtualScreen:0];
        floatSurface = colorFloat != 0;
    }
    CALayer *layer = contentLayer(window);
    if (layer) {
        if (@available(macOS 26.0, *)) {
            layerEnabled = ![layer.preferredDynamicRange isEqualToString:CADynamicRangeStandard];
            contentHeadroom = layer.contentsHeadroom;
        } else if ([layer respondsToSelector:@selector(wantsExtendedDynamicRangeContent)]) {
            layerEnabled = [[layer valueForKey:@"wantsExtendedDynamicRangeContent"] boolValue];
        }
    }

    return {
        {QStringLiteral("available"), true},
        {QStringLiteral("screenName"), QString::fromNSString(screen.localizedName)},
        {QStringLiteral("currentHeadroom"), current},
        {QStringLiteral("potentialHeadroom"), potential},
        {QStringLiteral("referenceHeadroom"), reference},
        {QStringLiteral("edrSupported"), potential > 1.0},
        {QStringLiteral("edrLayerEnabled"), layerEnabled},
        {QStringLiteral("layerFormat"), layer ? QString::fromNSString(layer.contentsFormat) : QString()},
        {QStringLiteral("contentHeadroom"), contentHeadroom},
        {QStringLiteral("floatSurface"), floatSurface},
        {QStringLiteral("surfaceColorBits"), colorBits},
        {QStringLiteral("outputColorSpace"), nativeWindow.colorSpace.localizedName
             ? QString::fromNSString(nativeWindow.colorSpace.localizedName) : QString()}
    };
}

}
#else
namespace MacWindowStyler {
bool prepareEdrRendering(QQuickWindow *) { return false; }
void apply(QQuickWindow *) {}
void setEdrEnabled(QQuickWindow *, bool) {}
QVariantMap displayHdrInfo(QQuickWindow *)
{
    return {{QStringLiteral("available"), false}};
}
}
#endif
