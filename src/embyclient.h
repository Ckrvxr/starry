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
    Q_PROPERTY(QVariantList servers READ servers NOTIFY serversChanged)
    Q_PROPERTY(QVariantList resumeItems READ resumeItems NOTIFY resumeItemsChanged)
    Q_PROPERTY(QVariantList hotItems READ hotItems NOTIFY hotItemsChanged)
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    Q_PROPERTY(QVariantList episodes READ episodes NOTIFY episodesChanged)
    Q_PROPERTY(QVariantMap currentItem READ currentItem NOTIFY currentItemChanged)

public:
    explicit EmbyClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    QString userName() const { return m_userName; }
    bool connected() const { return !m_token.isEmpty() && !m_userId.isEmpty(); }
    bool busy() const { return m_pendingRequests > 0; }
    QString error() const { return m_error; }
    QVariantList libraries() const { return m_libraries; }
    QVariantList servers() const { return m_servers; }
    QVariantList resumeItems() const { return m_resumeItems; }
    QVariantList hotItems() const { return m_hotItems; }
    QVariantList items() const { return m_items; }
    QVariantList episodes() const { return m_episodes; }
    QVariantMap currentItem() const { return m_currentItem; }

    Q_INVOKABLE void login(const QString &server, const QString &username, const QString &password,
                           const QString &displayName = {});
    Q_INVOKABLE void logout();
    Q_INVOKABLE void switchServer(const QString &url);
    Q_INVOKABLE void removeServer(const QString &url);
    Q_INVOKABLE void renameServer(const QString &url, const QString &displayName);
    Q_INVOKABLE void loadLibraries();
    Q_INVOKABLE void loadResume();
    Q_INVOKABLE void loadHot();
    Q_INVOKABLE void loadItems(const QString &parentId = {}, const QString &includeTypes = {});
    Q_INVOKABLE void loadEpisodes(const QString &seriesId);
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
    void serversChanged();
    void resumeItemsChanged();
    void hotItemsChanged();
    void itemsChanged();
    void episodesChanged();
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
    void reloadServers();

    QNetworkAccessManager m_network;
    QString m_serverUrl;
    QString m_token;
    QString m_userId;
    QString m_userName;
    QString m_deviceId;
    QString m_displayName;
    QString m_error;
    int m_pendingRequests = 0;
    QVariantList m_libraries;
    QVariantList m_servers;
    QVariantList m_resumeItems;
    QVariantList m_hotItems;
    QVariantList m_items;
    QVariantList m_episodes;
    QVariantMap m_currentItem;
};
