#include "embyclient.h"

#include <QCryptographicHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QSysInfo>
#include <QUrl>
#include <QUrlQuery>
#include <QUuid>

namespace {
constexpr auto kClientName = "Starry";
constexpr auto kClientVersion = "0.1.0";
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

void EmbyClient::login(const QString &server, const QString &username, const QString &password)
{
    m_serverUrl = normalizedServer(server);
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
        emit sessionChanged();
        emit loginSucceeded();
        loadLibraries();
    });
}

void EmbyClient::logout()
{
    m_token.clear();
    m_userId.clear();
    m_userName.clear();
    m_libraries.clear();
    m_items.clear();
    m_currentItem.clear();
    QSettings().clear();
    emit sessionChanged();
    emit librariesChanged();
    emit itemsChanged();
    emit currentItemChanged();
}

void EmbyClient::saveSession() const
{
    QSettings settings;
    settings.setValue("server", m_serverUrl);
    settings.setValue("token", m_token);
    settings.setValue("userId", m_userId);
    settings.setValue("userName", m_userName);
    settings.setValue("deviceId", m_deviceId);
}

void EmbyClient::restoreSession()
{
    QSettings settings;
    m_serverUrl = settings.value("server").toString();
    m_token = settings.value("token").toString();
    m_userId = settings.value("userId").toString();
    m_userName = settings.value("userName").toString();
    m_deviceId = settings.value("deviceId").toString();
    if (m_deviceId.isEmpty()) {
        m_deviceId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        settings.setValue("deviceId", m_deviceId);
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
        loadItems();
    });
}

void EmbyClient::loadItems(const QString &parentId, const QString &includeTypes)
{
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
