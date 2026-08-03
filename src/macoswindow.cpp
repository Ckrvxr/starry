#include "macoswindow.h"

#ifndef __APPLE__

#include <QQuickWindow>
#include <QRegion>
#include <QTimer>

#include <cmath>

namespace {

QRegion roundedRegion(const QSize &size, int radius)
{
    const int width = size.width();
    const int height = size.height();
    radius = qBound(0, radius, qMin(width, height) / 2);
    if (radius == 0)
        return QRegion(QRect(QPoint(0, 0), size));

    QRegion region;
    const double r = radius;
    for (int y = 0; y < height; ++y) {
        int inset = 0;
        if (y < radius) {
            const double dy = r - y - 0.5;
            inset = qMax(0, int(std::ceil(r - std::sqrt(qMax(0.0, r * r - dy * dy)))));
        } else if (y >= height - radius) {
            const double dy = y - (height - r) + 0.5;
            inset = qMax(0, int(std::ceil(r - std::sqrt(qMax(0.0, r * r - dy * dy)))));
        }
        if (width - inset * 2 > 0)
            region |= QRegion(inset, y, width - inset * 2, 1);
    }
    return region;
}

}

namespace MacWindowStyler {

bool prepareEdrRendering(QQuickWindow *)
{
    return false;
}

void apply(QQuickWindow *window)
{
    if (!window)
        return;

    const auto updateMask = [window] {
        if (!window->isVisible() || window->width() <= 0 || window->height() <= 0)
            return;
        window->setMask(roundedRegion(window->size(), 18));
    };

    QObject::connect(window, &QQuickWindow::widthChanged, window, updateMask);
    QObject::connect(window, &QQuickWindow::heightChanged, window, updateMask);
    QTimer::singleShot(0, window, updateMask);
}

void setEdrEnabled(QQuickWindow *, bool)
{
}

QVariantMap displayHdrInfo(QQuickWindow *)
{
    return {
        {QStringLiteral("available"), false},
        {QStringLiteral("edrSupported"), false},
        {QStringLiteral("edrLayerEnabled"), false}
    };
}

}

#else

// macOS 使用 macoswindow.mm 中的 Cocoa CALayer 圆角实现。

#endif
