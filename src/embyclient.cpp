#include "embyclient.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QSysInfo>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

namespace {
constexpr auto kClientName = "Starry";
constexpr auto kClientVersion = "0.1.0";

QString dbPath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dir);
    return dir + QStringLiteral("/starry.db");
}

QSqlDatabase openDb()
{
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("starry"), /* open= */ false);
    if (!db.isValid()) {
        db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("starry"));
        db.setDatabaseName(dbPath());
        if (!db.open()) {
            qWarning() << "SQLite 打开失败:" << db.lastError().text();
            return {};
        }
        QSqlQuery query(db);
        query.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
        query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS servers ("
                                   "server_url TEXT PRIMARY KEY, token TEXT NOT NULL, "
                                   "user_id TEXT NOT NULL, user_name TEXT NOT NULL, "
                                   "device_id TEXT NOT NULL, last_used INTEGER NOT NULL, "
                                   "display_name TEXT NOT NULL DEFAULT '')"));
        // 旧库补 display_name 列
        QSqlQuery columns(db);
        columns.exec(QStringLiteral("PRAGMA table_info(servers)"));
        bool hasDisplayName = false;
        while (columns.next()) {
            if (columns.value(1).toString() == QStringLiteral("display_name"))
                hasDisplayName = true;
        }
        if (!hasDisplayName) {
            query.exec(QStringLiteral("ALTER TABLE servers "
                                       "ADD COLUMN display_name TEXT NOT NULL DEFAULT ''"));
        }
    }
    return db;
}
}

EmbyClient::EmbyClient(QObject *parent)
    : QObject(parent)
{
    restoreSession();
}

QString EmbyClient::normalizedServer(const QString &server) const
{
    QString value = server.trimmed();
    if (!value.startsWith("http://") && !value.startsWith("https://"))
        value.prepend("http://");
    while (value.endsWith('/'))
        value.chop(1);
    return value;
}

QString EmbyClient::authHeader() const
{
    return QStringLiteral("MediaBrowser Client=\"%1\", Device=\"%2\", DeviceId=\"%3\", Version=\"%4\", Token=\"%5\"")
        .arg(kClientName, QSysInfo::prettyProductName(), m_deviceId, kClientVersion, m_token);
}

void EmbyClient::beginRequest()
{
    const bool wasBusy = busy();
    ++m_pendingRequests;
    if (wasBusy != busy())
        emit busyChanged();
}

void EmbyClient::endRequest()
{
    const bool wasBusy = busy();
    m_pendingRequests = qMax(0, m_pendingRequests - 1);
    if (wasBusy != busy())
        emit busyChanged();
}

void EmbyClient::setError(const QString &message)
{
    if (m_error == message)
        return;
    m_error = message;
    emit errorChanged();
}

void EmbyClient::clearError()
{
    setError({});
}

void EmbyClient::request(const QString &method, const QString &path, const QJsonObject &body,
                         JsonHandler handler, bool trackBusy)
{
    QUrl url(path.startsWith("http") ? path : m_serverUrl + path);
    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("X-Emby-Authorization", authHeader().toUtf8());
    if (!m_token.isEmpty())
        req.setRawHeader("X-Emby-Token", m_token.toUtf8());

    const QByteArray payload = body.isEmpty() ? QByteArray() : QJsonDocument(body).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = nullptr;
    if (method == "GET")
        reply = m_network.get(req);
    else if (method == "POST")
        reply = m_network.post(req, payload);
    else
        reply = m_network.sendCustomRequest(req, method.toUtf8(), payload);

    if (trackBusy)
        beginRequest();
    connect(reply, &QNetworkReply::finished, this, [this, reply, handler = std::move(handler), trackBusy] {
        if (trackBusy)
            endRequest();
        const QByteArray bytes = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || status >= 400) {
            QString message = reply->errorString();
            const QJsonObject errorObject = QJsonDocument::fromJson(bytes).object();
            if (!errorObject.value("Message").toString().isEmpty())
                message = errorObject.value("Message").toString();
            setError(message);
            reply->deleteLater();
            return;
        }
        setError({});
        if (handler)
            handler(QJsonDocument::fromJson(bytes).object());
        reply->deleteLater();
    });
}

void EmbyClient::login(const QString &server, const QString &username, const QString &password,
                       const QString &displayName)
{
    m_serverUrl = normalizedServer(server);
    m_displayName = displayName.trimmed();
    m_token.clear();
    m_userId.clear();
    m_userName.clear();
    emit sessionChanged();

    QJsonObject body{{"Username", username}, {"Pw", password}};
    request("POST", "/emby/Users/AuthenticateByName", body, [this](const QJsonObject &json) {
        const QJsonObject user = json.value("User").toObject();
        m_token = json.value("AccessToken").toString();
        m_userId = user.value("Id").toString();
        m_userName = user.value("Name").toString();
        if (!connected()) {
            setError(tr("服务器返回了无效的登录信息"));
            return;
        }
        saveSession();
        reloadServers();
        emit serversChanged();
        emit sessionChanged();
        emit loginSucceeded();
        loadLibraries();
    });
}

void EmbyClient::logout()
{
    const QString url = m_serverUrl;
    m_serverUrl.clear();
    m_token.clear();
    m_userId.clear();
    m_userName.clear();
    m_displayName.clear();
    m_libraries.clear();
    m_hotItems.clear();
    m_items.clear();
    m_episodes.clear();
    m_currentItem.clear();
    // 退出登录 = 删除当前服务器的凭据记录，其他服务器保留
    QSqlDatabase db = openDb();
    if (db.isValid() && !url.isEmpty()) {
        QSqlQuery query(db);
        query.prepare(QStringLiteral("DELETE FROM servers WHERE server_url = ?"));
        query.addBindValue(url);
        query.exec();
    }
    reloadServers();
    emit serversChanged();
    emit sessionChanged();
    emit librariesChanged();
    emit hotItemsChanged();
    emit itemsChanged();
    emit episodesChanged();
    emit currentItemChanged();
}

void EmbyClient::switchServer(const QString &url)
{
    if (url == m_serverUrl || url.isEmpty())
        return;
    QSqlDatabase db = openDb();
    if (!db.isValid())
        return;
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT token, user_id, user_name, device_id, display_name "
                                  "FROM servers WHERE server_url = ?"));
    query.addBindValue(url);
    if (!query.exec() || !query.next()) {
        setError(tr("服务器记录不存在"));
        return;
    }
    m_serverUrl = url;
    m_token = query.value(0).toString();
    m_userId = query.value(1).toString();
    m_userName = query.value(2).toString();
    m_deviceId = query.value(3).toString();
    m_displayName = query.value(4).toString();
    m_libraries.clear();
    m_hotItems.clear();
    m_items.clear();
    m_episodes.clear();
    m_currentItem.clear();
    emit sessionChanged();
    emit librariesChanged();
    emit hotItemsChanged();
    emit itemsChanged();
    emit episodesChanged();
    emit currentItemChanged();
    saveSession(); // 更新 last_used
    loadLibraries();
}

void EmbyClient::removeServer(const QString &url)
{
    QSqlDatabase db = openDb();
    if (db.isValid()) {
        QSqlQuery query(db);
        query.prepare(QStringLiteral("DELETE FROM servers WHERE server_url = ?"));
        query.addBindValue(url);
        query.exec();

        // 一并清理该服务器的图片缓存（image_cache 行 + 磁盘文件）
        const QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                                 + QStringLiteral("/imagecache");
        QSqlQuery all(db);
        QStringList doomedFiles;
        if (all.exec(QStringLiteral("SELECT url, file FROM image_cache"))) {
            while (all.next()) {
                if (all.value(0).toString().startsWith(url))
                    doomedFiles << all.value(1).toString();
            }
        }
        db.transaction();
        {
            QSqlQuery del(db);
            del.prepare(QStringLiteral("DELETE FROM image_cache WHERE url LIKE ?"));
            del.addBindValue(url + QLatin1Char('%'));
            del.exec();
        }
        db.commit();
        for (const QString &file : doomedFiles)
            QFile::remove(cacheDir + QLatin1Char('/') + file);
    }
    if (url == m_serverUrl) {
        m_serverUrl.clear();
        m_token.clear();
        m_userId.clear();
        m_userName.clear();
        m_displayName.clear();
        m_libraries.clear();
        m_hotItems.clear();
        m_items.clear();
        m_episodes.clear();
        m_currentItem.clear();
        emit sessionChanged();
        emit librariesChanged();
        emit hotItemsChanged();
        emit itemsChanged();
        emit episodesChanged();
        emit currentItemChanged();
    }
    reloadServers();
    emit serversChanged();
}

void EmbyClient::renameServer(const QString &url, const QString &displayName)
{
    QSqlDatabase db = openDb();
    if (db.isValid()) {
        QSqlQuery query(db);
        query.prepare(QStringLiteral("UPDATE servers SET display_name = ? WHERE server_url = ?"));
        query.addBindValue(displayName.trimmed());
        query.addBindValue(url);
        query.exec();
    }
    if (url == m_serverUrl)
        m_displayName = displayName.trimmed();
    reloadServers();
    emit serversChanged();
}

void EmbyClient::reloadServers()
{
    m_servers.clear();
    QSqlDatabase db = openDb();
    if (!db.isValid())
        return;
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT server_url, user_name, display_name FROM servers "
                                    "ORDER BY last_used DESC")))
        return;
    while (query.next())
        m_servers.append(QVariantMap{
            {"url", query.value(0).toString()},
            {"userName", query.value(1).toString()},
            {"displayName", query.value(2).toString()}
        });
}

void EmbyClient::saveSession() const
{
    if (m_serverUrl.isEmpty())
        return;
    QSqlDatabase db = openDb();
    if (!db.isValid())
        return;
    QSqlQuery query(db);
    query.prepare(QStringLiteral("INSERT INTO servers(server_url, token, user_id, user_name, "
                                  "device_id, last_used, display_name) VALUES(?, ?, ?, ?, ?, ?, ?) "
                                  "ON CONFLICT(server_url) DO UPDATE SET "
                                  "token = excluded.token, user_id = excluded.user_id, "
                                  "user_name = excluded.user_name, device_id = excluded.device_id, "
                                  "last_used = excluded.last_used, "
                                  "display_name = excluded.display_name"));
    query.addBindValue(m_serverUrl);
    query.addBindValue(m_token);
    query.addBindValue(m_userId);
    query.addBindValue(m_userName);
    query.addBindValue(m_deviceId);
    query.addBindValue(QDateTime::currentMSecsSinceEpoch());
    query.addBindValue(m_displayName);
    query.exec();
}

void EmbyClient::restoreSession()
{
    reloadServers();
    QSqlDatabase db = openDb();
    if (!db.isValid())
        return;

    // 恢复最近使用的服务器
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral("SELECT server_url, token, user_id, user_name, device_id, "
                                    "display_name FROM servers ORDER BY last_used DESC LIMIT 1")))
        return;
    if (!query.next())
        return;
    m_serverUrl = query.value(0).toString();
    m_token = query.value(1).toString();
    m_userId = query.value(2).toString();
    m_userName = query.value(3).toString();
    m_deviceId = query.value(4).toString();
    m_displayName = query.value(5).toString();
    if (m_deviceId.isEmpty()) {
        m_deviceId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        saveSession();
    }
    if (connected())
        loadLibraries();
}

QVariantMap EmbyClient::mapItem(const QJsonObject &item) const
{
    const qint64 ticks = item.value("RunTimeTicks").toVariant().toLongLong();
    const QJsonObject userData = item.value("UserData").toObject();
    const qint64 positionTicks = userData.value("PlaybackPositionTicks").toVariant().toLongLong();
    const QString type = item.value("Type").toString();
    const QJsonArray genres = item.value("Genres").toArray();
    const QString genre = genres.isEmpty() ? QString() : genres.first().toString();
    QString subtitle;
    if (type == "Episode") {
        subtitle = tr("第 %1 季 · 第 %2 集")
            .arg(item.value("ParentIndexNumber").toInt())
            .arg(item.value("IndexNumber").toInt());
    } else {
        subtitle = item.value("ProductionYear").toVariant().toString();
    }
    return {
        {"id", item.value("Id").toString()},
        {"name", item.value("Name").toString()},
        {"type", type},
        {"year", item.value("ProductionYear").toVariant().toString()},
        {"genre", genre},
        {"seasonNumber", item.value("ParentIndexNumber").toInt()},
        {"indexNumber", item.value("IndexNumber").toInt()},
        {"premiereDate", item.value("PremiereDate").toString().left(10)},
        {"overview", item.value("Overview").toString()},
        {"subtitle", subtitle},
        {"communityRating", item.value("CommunityRating").toDouble()},
        {"duration", ticks / 10000000.0},
        {"position", positionTicks / 10000000.0},
        {"played", userData.value("Played").toBool()},
        {"favorite", userData.value("IsFavorite").toBool()},
        {"image", imageUrl(item.value("Id").toString())},
        {"backdrop", imageUrl(item.value("Id").toString(), "Backdrop", 1600)},
        {"seriesName", item.value("SeriesName").toString()}
    };
}

void EmbyClient::loadLibraries()
{
    if (!connected())
        return;
    request("GET", QStringLiteral("/emby/Users/%1/Views").arg(m_userId), {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_libraries = next;
        emit librariesChanged();
        loadHot();
        loadItems();
        loadResume();
    });
}

void EmbyClient::loadHot()
{
    if (!connected())
        return;
    QUrlQuery query;
    const QString threeMonthsAgo = QDateTime::currentDateTimeUtc().addMonths(-3).toString(Qt::ISODate);
    query.addQueryItem("Recursive", "true");
    query.addQueryItem("MinDateLastSavedForUser", threeMonthsAgo);
    query.addQueryItem("SortBy", "PlayCount");
    query.addQueryItem("SortOrder", "Descending");
    query.addQueryItem("Limit", "5");
    query.addQueryItem("Fields", "Overview,Genres,PremiereDate,PrimaryImageAspectRatio,SeriesName,ParentIndexNumber,IndexNumber");
    query.addQueryItem("EnableUserData", "true");
    query.addQueryItem("IncludeItemTypes", "Movie,Episode");
    const QString path = QStringLiteral("/emby/Users/%1/Items?%2")
        .arg(m_userId, query.toString(QUrl::FullyEncoded));
    request("GET", path, {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_hotItems = next;
        emit hotItemsChanged();
    });
}

void EmbyClient::loadResume()
{
    if (!connected())
        return;
    QUrlQuery query;
    query.addQueryItem("Limit", "12");
    query.addQueryItem("Fields", "Overview,PrimaryImageAspectRatio,SeriesName,ParentIndexNumber,IndexNumber");
    const QString path = QStringLiteral("/emby/Users/%1/Items/Resume?%2")
        .arg(m_userId, query.toString(QUrl::FullyEncoded));
    request("GET", path, {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_resumeItems = next;
        emit resumeItemsChanged();
    });
}

void EmbyClient::loadItems(const QString &parentId, const QString &includeTypes){
    if (!connected())
        return;
    QUrlQuery query;
    query.addQueryItem("Recursive", "true");
    query.addQueryItem("SortBy", "DateCreated,SortName");
    query.addQueryItem("SortOrder", "Descending");
    query.addQueryItem("Limit", "100");
    query.addQueryItem("Fields", "Overview,Genres,PremiereDate,PrimaryImageAspectRatio,MediaSourceCount");
    query.addQueryItem("EnableUserData", "true");
    if (!parentId.isEmpty())
        query.addQueryItem("ParentId", parentId);
    query.addQueryItem("IncludeItemTypes", includeTypes.isEmpty() ? "Movie,Episode" : includeTypes);
    const QString path = QStringLiteral("/emby/Users/%1/Items?%2").arg(m_userId, query.toString(QUrl::FullyEncoded));
    request("GET", path, {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_items = next;
        emit itemsChanged();
    });
}

void EmbyClient::loadEpisodes(const QString &seriesId)
{
    m_episodes.clear();
    emit episodesChanged();
    if (!connected() || seriesId.isEmpty())
        return;

    QUrlQuery query;
    query.addQueryItem("Recursive", "true");
    query.addQueryItem("SortBy", "ParentIndexNumber,IndexNumber");
    query.addQueryItem("SortOrder", "Ascending");
    query.addQueryItem("Limit", "1000");
    query.addQueryItem("Fields", "Overview,Genres,PremiereDate,PrimaryImageAspectRatio,MediaSourceCount");
    query.addQueryItem("EnableUserData", "true");
    query.addQueryItem("ParentId", seriesId);
    query.addQueryItem("IncludeItemTypes", "Episode");
    const QString path = QStringLiteral("/emby/Users/%1/Items?%2").arg(m_userId, query.toString(QUrl::FullyEncoded));
    request("GET", path, {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_episodes = next;
        emit episodesChanged();
    });
}

void EmbyClient::search(const QString &term)
{
    if (term.trimmed().isEmpty()) {
        loadItems();
        return;
    }
    QUrlQuery query;
    query.addQueryItem("SearchTerm", term.trimmed());
    query.addQueryItem("Recursive", "true");
    query.addQueryItem("Limit", "100");
    query.addQueryItem("IncludeItemTypes", "Movie,Series,Episode");
    query.addQueryItem("Fields", "Overview,Genres,PremiereDate,PrimaryImageAspectRatio");
    const QString path = QStringLiteral("/emby/Users/%1/Items?%2").arg(m_userId, query.toString(QUrl::FullyEncoded));
    request("GET", path, {}, [this](const QJsonObject &json) {
        QVariantList next;
        for (const QJsonValue &value : json.value("Items").toArray())
            next.append(mapItem(value.toObject()));
        m_items = next;
        emit itemsChanged();
    });
}

void EmbyClient::loadItem(const QString &id)
{
    if (id.isEmpty())
        return;
    m_currentItem.clear();
    emit currentItemChanged();
    request("GET", QStringLiteral("/emby/Users/%1/Items/%2").arg(m_userId, id), {}, [this](const QJsonObject &json) {
        m_currentItem = mapItem(json);
        emit currentItemChanged();
    });
}

QString EmbyClient::imageUrl(const QString &id, const QString &type, int width) const
{
    if (id.isEmpty() || m_serverUrl.isEmpty())
        return {};
    QUrl url(QStringLiteral("%1/emby/Items/%2/Images/%3").arg(m_serverUrl, id, type));
    QUrlQuery query;
    query.addQueryItem("maxWidth", QString::number(width));
    query.addQueryItem("quality", "90");
    if (!m_token.isEmpty())
        query.addQueryItem("api_key", m_token);
    url.setQuery(query);
    return url.toString();
}

QString EmbyClient::playbackUrl(const QString &id) const
{
    QUrl url(QStringLiteral("%1/emby/Videos/%2/stream").arg(m_serverUrl, id));
    QUrlQuery query;
    query.addQueryItem("static", "true");
    query.addQueryItem("api_key", m_token);
    query.addQueryItem("DeviceId", m_deviceId);
    url.setQuery(query);
    return url.toString();
}

void EmbyClient::reportPlaybackStart(const QString &id)
{
    request("POST", "/emby/Sessions/Playing", {{"ItemId", id}, {"PlayMethod", "DirectPlay"}, {"CanSeek", true}}, {}, false);
}

void EmbyClient::reportPlaybackProgress(const QString &id, double seconds, bool paused)
{
    request("POST", "/emby/Sessions/Playing/Progress", {
        {"ItemId", id},
        {"PositionTicks", seconds * 10000000.0},
        {"IsPaused", paused},
        {"PlayMethod", "DirectPlay"},
        {"CanSeek", true}
    }, {}, false);
}

void EmbyClient::reportPlaybackStopped(const QString &id, double seconds)
{
    request("POST", "/emby/Sessions/Playing/Stopped", {
        {"ItemId", id},
        {"PositionTicks", seconds * 10000000.0}
    }, {}, false);
}
