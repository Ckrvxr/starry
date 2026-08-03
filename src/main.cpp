#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QQuickStyle>

#include <clocale>

#include "embyclient.h"
#include "imagecache.h"
#include "mpvplayer.h"
#include "macoswindow.h"
#include "settingsstore.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("Starry"));
    QCoreApplication::setApplicationName(QStringLiteral("Starry"));
    QCoreApplication::setApplicationVersion(QStringLiteral(STARRY_VERSION));
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);

    // Qt 在 macOS 上会把 locale 设为系统区域设置，而 libmpv 要求 C locale
    // （否则 mpv_create 直接返回 NULL）。必须在 QGuiApplication 构造后复位。
    std::setlocale(LC_NUMERIC, "C");

    qmlRegisterType<MpvPlayer>("Starry", 1, 0, "MpvPlayer");

    EmbyClient emby;
    SettingsStore settings;
    QQmlApplicationEngine engine;
    engine.addImageProvider(QStringLiteral("cached"), new CachedImageProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("emby"), &emby);
    engine.rootContext()->setContextProperty(QStringLiteral("settings"), &settings);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("Starry", "Main");

    if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
        MacWindowStyler::apply(window);
        QMetaObject::invokeMethod(window, [window] { MacWindowStyler::apply(window); }, Qt::QueuedConnection);
    }

    return app.exec();
}
