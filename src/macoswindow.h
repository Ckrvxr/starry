#pragma once

#include <QVariantMap>

class QQuickWindow;

namespace MacWindowStyler {
bool prepareEdrRendering(QQuickWindow *window);
void apply(QQuickWindow *window);
void setEdrEnabled(QQuickWindow *window, bool enabled);
QVariantMap displayHdrInfo(QQuickWindow *window);
}
