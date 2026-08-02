#pragma once

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class EmbyClient final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl NOTIFY sessionChanged)
    Q_PROPERTY(QString userName READ userName NOTIFY sessionChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY sessionChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(QVariantList libraries READ libraries NOTIFY librariesChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(QVariantMap currentItem READ currentItem NOTIFY currentItemChanged)

public:
    explicit EmbyClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    QString userName() const { return m_userName; }
    bool connected() const { return !m_token.isEmpty() && !m_userId.isEmpty(); }
    bool busy() const { return m_pendingRequests > 0; }
    QString error() const { return m_error; }
    QVariantList libraries() const { return m_libraries; }
    QVariantList items() const { return m_items; }
    QVariantMap currentItem() const { return m_currentItem; }

    Q_INVOKABLE void login(const QString &server, const QString &username, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void loadLibraries();
    Q_INVOKABLE void loadItems(const QString &parentId = {}, const QString &includeTypes = {});
    Q_INVOKABLE void search(const QString &term);
    Q_INVOKABLE void loadItem(const QString &id);
    Q_INVOKABLE QString imageUrl(const QString &id, const QString &type = QStringLiteral("Primary"), int width = 480) const;
    Q_INVOKABLE QString playbackUrl(const QString &id) const;
    Q_INVOKABLE void reportPlaybackStart(const QString &id);
    Q_INVOKABLE void reportPlaybackProgress(const QString &id, double seconds, bool paused);
    Q_INVOKABLE void reportPlaybackStopped(const QString &id, double seconds);
    Q_INVOKABLE void clearError();

signals:
    void sessionChanged();
    void busyChanged();
    void errorChanged();
    void librariesChanged();
    void itemsChanged();
    void currentItemChanged();
    void loginSucceeded();

private:
    using JsonHandler = std::function<void(const QJsonObject &)>;
    void request(const QString &method, const QString &path, const QJsonObject &body,
                 JsonHandler handler = {}, bool trackBusy = true);
    void setError(const QString &message);
    void beginRequest();
    void endRequest();
    QString normalizedServer(const QString &server) const;
    QString authHeader() const;
    QVariantMap mapItem(const QJsonObject &item) const;
    void saveSession() const;
    void restoreSession();

    QNetworkAccessManager m_network;
    QString m_serverUrl;
    QString m_token;
    QString m_userId;
    QString m_userName;
    QString m_deviceId;
    QString m_error;
    int m_pendingRequests = 0;
    QVariantList m_libraries;
    QVariantList m_items;
    QVariantMap m_currentItem;
};
