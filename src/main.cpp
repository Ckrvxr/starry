#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QQuickStyle>

#include "embyclient.h"
#include "mpvplayer.h"
#include "macoswindow.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName(QStringLiteral("Starry"));
    QCoreApplication::setApplicationName(QStringLiteral("Starry"));
    QCoreApplication::setApplicationVersion(QStringLiteral(STARRY_VERSION));
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);

    qmlRegisterType<MpvPlayer>("Starry", 1, 0, "MpvPlayer");

    EmbyClient emby;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("emby"), &emby);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("Starry", "Main");

    if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
        MacWindowStyler::apply(window);
        QMetaObject::invokeMethod(window, [window] { MacWindowStyler::apply(window); }, Qt::QueuedConnection);
    }

    return app.exec();
}
