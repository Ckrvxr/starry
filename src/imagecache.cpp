#include "imagecache.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QNetworkReply>
#include <QQuickTextureFactory>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>

namespace {
constexpr int kCacheCapacity = 1000;

QString cacheDir()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                        + QStringLiteral("/imagecache");
    QDir().mkpath(dir);
    return dir;
}

QSqlDatabase cacheDb()
{
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("imagecache"), /* open= */ false);    if (!db.isValid()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("imagecache"));
        db.setDatabaseName(dir + QStringLiteral("/starry.db"));
        if (!db.open()) {
            qWarning() << "图片缓存库打开失败:" << db.lastError().text();
            return {};
        }
        QSqlQuery query(db);
        query.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
        query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS image_cache ("
                                  "url TEXT PRIMARY KEY, file TEXT NOT NULL, "
                                  "size INTEGER NOT NULL, last_access INTEGER NOT NULL)"));

        // 启动清理：DB 有但文件缺失的行，以及文件存在但无 DB 记录的文件
        QStringList knownFiles;
        QSqlQuery filesQuery(db);
        if (filesQuery.exec(QStringLiteral("SELECT file FROM image_cache"))) {
            while (filesQuery.next())
                knownFiles << filesQuery.value(0).toString();
        }
        QSqlQuery rows(db);
        if (rows.exec(QStringLiteral("SELECT url, file FROM image_cache"))) {
            while (rows.next()) {
                if (!QFile::exists(cacheDir() + QLatin1Char('/') + rows.value(1).toString())) {
                    QSqlQuery del(db);
                    del.prepare(QStringLiteral("DELETE FROM image_cache WHERE url = ?"));
                    del.addBindValue(rows.value(0).toString());
                    del.exec();
                }
            }
        }
        const QDir cacheDirObj(cacheDir());
        const QStringList orphans = cacheDirObj.entryList({QStringLiteral("*.img")}, QDir::Files);
        for (const QString &name : orphans) {
            if (!knownFiles.contains(name))
                QFile::remove(cacheDirObj.filePath(name));
        }
    }
    return db;
}

QString hashName(const QString &url)
{
    return QString::fromLatin1(
        QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex())
        + QStringLiteral(".img");
}

// 磁盘命中：读取并解码缓存图片；文件缺失时顺带清理孤儿行
QImage loadFromDisk(const QString &url)
{
    QSqlDatabase db = cacheDb();
    if (!db.isValid())
        return {};
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT file FROM image_cache WHERE url = ?"));
    query.addBindValue(url);
    if (!query.exec() || !query.next())
        return {};
    const QString file = query.value(0).toString();
    QFile f(cacheDir() + QLatin1Char('/') + file);
    if (!f.open(QIODevice::ReadOnly)) {
        QSqlQuery del(db);
        del.prepare(QStringLiteral("DELETE FROM image_cache WHERE url = ?"));
        del.addBindValue(url);
        del.exec();
        return {};
    }
    const QImage image = QImage::fromData(f.readAll());
    if (image.isNull()) {
        QFile::remove(cacheDir() + QLatin1Char('/') + file);
        QSqlQuery del(db);
        del.prepare(QStringLiteral("DELETE FROM image_cache WHERE url = ?"));
        del.addBindValue(url);
        del.exec();
    }
    return image;
}

// 磁盘写入 + LRU 淘汰（保留最近访问的 kCacheCapacity 项）
void storeToDisk(const QString &url, const QByteArray &bytes)
{
    QSqlDatabase db = cacheDb();
    if (!db.isValid())
        return;
    const QString file = hashName(url);
    QFile f(cacheDir() + QLatin1Char('/') + file);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "图片缓存写入失败:" << f.errorString();
        return;
    }
    f.write(bytes);
    f.close();

    db.transaction();
    {
        QSqlQuery upsert(db);
        upsert.prepare(QStringLiteral("INSERT INTO image_cache(url, file, size, last_access) "
                                      "VALUES(?, ?, ?, ?) "
                                      "ON CONFLICT(url) DO UPDATE SET file = excluded.file, "
                                      "size = excluded.size, last_access = excluded.last_access"));
        upsert.addBindValue(url);
        upsert.addBindValue(file);
        upsert.addBindValue(bytes.size());
        upsert.addBindValue(QDateTime::currentMSecsSinceEpoch());
        upsert.exec();

        QSqlQuery prune(db);
        if (prune.exec(QStringLiteral(
                "SELECT url FROM image_cache ORDER BY last_access DESC LIMIT -1 OFFSET %1")
                           .arg(kCacheCapacity))) {
            while (prune.next()) {
                const QString oldUrl = prune.value(0).toString();
                QSqlQuery del(db);
                del.prepare(QStringLiteral("DELETE FROM image_cache WHERE url = ?"));
                del.addBindValue(oldUrl);
                del.exec();
                QFile::remove(cacheDir() + QLatin1Char('/') + hashName(oldUrl));
            }
        }
    }
    db.commit();
}

void touchAccess(const QString &url)
{
    QSqlDatabase db = cacheDb();
    if (!db.isValid())
        return;
    QSqlQuery query(db);
    query.prepare(QStringLiteral("UPDATE image_cache SET last_access = ? WHERE url = ?"));
    query.addBindValue(QDateTime::currentMSecsSinceEpoch());
    query.addBindValue(url);
    query.exec();
}
} // namespace

CachedImageProvider::CachedImageProvider()
    : QQuickAsyncImageProvider()
    , m_cache(kCacheCapacity)
{
}

QQuickImageResponse *CachedImageProvider::requestImageResponse(const QString &id,
                                                               const QSize &requestedSize)
{
    Q_UNUSED(requestedSize);
    // requestImageResponse 在 QQuickPixmapReader 线程调用，而 QNetworkAccessManager、
    // QCache 与 SQLite 连接属 GUI 线程；排队到 GUI 线程再处理。
    auto *response = new CachedImageResponse;
    QMetaObject::invokeMethod(this, [response, id, this] {
        response->start(&m_network, &m_cache, id);
    }, Qt::QueuedConnection);
    return response;
}

void CachedImageResponse::start(QNetworkAccessManager *network,
                                QCache<QString, QImage> *cache,
                                const QString &encodedUrl)
{
    m_cache = cache;
    // QML 传入的 id 是 encodeURIComponent 后的 URL，这里做一次解码兜底
    // （Qt 可能已解码或未解码，两种情况都安全：未解码时按百分号解码，
    //  已解码时字符串中已无 % 序列）。
    m_url = QString::fromUtf8(QByteArray::fromPercentEncoding(encodedUrl.toUtf8()));

    // 1) 内存缓存
    if (QImage *hit = m_cache->object(m_url)) {
        m_image = *hit;
        QTimer::singleShot(0, this, &QQuickImageResponse::finished);
        return;
    }
    // 2) 磁盘缓存（离线可用）
    m_image = loadFromDisk(m_url);
    if (!m_image.isNull()) {
        m_cache->insert(m_url, new QImage(m_image));
        touchAccess(m_url);
        QTimer::singleShot(0, this, &QQuickImageResponse::finished);
        return;
    }
    // 3) 网络加载，成功后写入内存与磁盘
    m_reply = network->get(QNetworkRequest(QUrl(m_url)));
    connect(m_reply, &QNetworkReply::finished, this, &CachedImageResponse::onReplyFinished);
}

QQuickTextureFactory *CachedImageResponse::textureFactory() const
{
    return QQuickTextureFactory::textureFactoryForImage(m_image);
}

QString CachedImageResponse::errorString() const
{
    return m_error;
}

void CachedImageResponse::onReplyFinished()
{
    if (m_reply->error() == QNetworkReply::NoError) {
        const QByteArray bytes = m_reply->readAll();
        m_image = QImage::fromData(bytes);
        if (m_image.isNull()) {
            m_error = QStringLiteral("图片解码失败");
        } else {
            m_cache->insert(m_url, new QImage(m_image));
            storeToDisk(m_url, bytes);
        }
    } else {
        m_error = m_reply->errorString();
    }
    m_reply->deleteLater();
    m_reply = nullptr;
    emit finished();
}
