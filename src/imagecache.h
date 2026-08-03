#pragma once

#include <QCache>
#include <QImage>
#include <QNetworkAccessManager>
#include <QQuickAsyncImageProvider>
#include <QQuickImageResponse>

// 网络图片的 LRU 缓存 ImageProvider（上限 1000 项，QCache 淘汰最久未使用项）。
// QML 用法: Image { source: "image://cached/" + encodeURIComponent(url) }
class CachedImageProvider final : public QQuickAsyncImageProvider
{
public:
    CachedImageProvider();

    QQuickImageResponse *requestImageResponse(const QString &id,
                                              const QSize &requestedSize) override;

private:
    QNetworkAccessManager m_network;
    QCache<QString, QImage> m_cache; // 容量 1000 项，LRU
};

class CachedImageResponse final : public QQuickImageResponse
{
public:
    // 必须在 QNetworkAccessManager 所属线程（GUI 线程）调用
    void start(QNetworkAccessManager *network, QCache<QString, QImage> *cache,
               const QString &encodedUrl);

    QQuickTextureFactory *textureFactory() const override;
    QString errorString() const override;

private:
    void onReplyFinished();

    QNetworkReply *m_reply = nullptr;
    QCache<QString, QImage> *m_cache = nullptr;
    QString m_url;
    QString m_error;
    QImage m_image;
};
