#include "mpvplayer.h"

#include <QMetaObject>
#include <QOpenGLContext>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QQuickOpenGLUtils>
#include <QQuickWindow>

#include <mpv/client.h>
#include <mpv/render_gl.h>
#include <utility>
#include <vector>

namespace {
void *getProcAddress(void *, const char *name)
{
    QOpenGLContext *context = QOpenGLContext::currentContext();
    return context ? reinterpret_cast<void *>(context->getProcAddress(QByteArray(name))) : nullptr;
}

QVariant nodeToVariant(const mpv_node &node)
{
    switch (node.format) {
    case MPV_FORMAT_STRING:
    case MPV_FORMAT_OSD_STRING:
        return node.u.string ? QString::fromUtf8(node.u.string) : QString();
    case MPV_FORMAT_FLAG:
        return node.u.flag != 0;
    case MPV_FORMAT_INT64:
        return QVariant::fromValue(node.u.int64);
    case MPV_FORMAT_DOUBLE:
        return node.u.double_;
    case MPV_FORMAT_NODE_ARRAY: {
        QVariantList values;
        if (!node.u.list)
            return values;
        values.reserve(node.u.list->num);
        for (int index = 0; index < node.u.list->num; ++index)
            values.append(nodeToVariant(node.u.list->values[index]));
        return values;
    }
    case MPV_FORMAT_NODE_MAP: {
        QVariantMap values;
        if (!node.u.list)
            return values;
        for (int index = 0; index < node.u.list->num; ++index) {
            const QString key = node.u.list->keys[index]
                ? QString::fromUtf8(node.u.list->keys[index]) : QString();
            values.insert(key, nodeToVariant(node.u.list->values[index]));
        }
        return values;
    }
    default:
        return {};
    }
}
}

class MpvRenderer final : public QQuickFramebufferObject::Renderer
{
public:
    explicit MpvRenderer(MpvPlayer *player) : m_player(player)
    {
        if (!player->m_mpv)
            return;
        mpv_opengl_init_params glInit{getProcAddress, nullptr};
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(MPV_RENDER_API_TYPE_OPENGL)},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &glInit},
            {MPV_RENDER_PARAM_INVALID, nullptr}
        };
        if (mpv_render_context_create(&m_context, player->m_mpv, params) < 0) {
            QMetaObject::invokeMethod(player, [player] { emit player->mpvError(QStringLiteral("无法创建 libmpv OpenGL 渲染上下文")); });
            return;
        }
        mpv_render_context_set_update_callback(m_context, &MpvRenderer::onUpdate, this);
    }

    ~MpvRenderer() override
    {
        if (m_context) {
            mpv_render_context_set_update_callback(m_context, nullptr, nullptr);
            mpv_render_context_free(m_context);
        }
    }

    QOpenGLFramebufferObject *createFramebufferObject(const QSize &size) override
    {
        QOpenGLFramebufferObjectFormat format;
        format.setAttachment(QOpenGLFramebufferObject::CombinedDepthStencil);
        return new QOpenGLFramebufferObject(size, format);
    }

    void render() override
    {
        if (!m_context)
            return;
        QOpenGLFramebufferObject *fbo = framebufferObject();
        mpv_opengl_fbo target{static_cast<int>(fbo->handle()), fbo->width(), fbo->height(), 0};
        // Qt Quick already presents the framebuffer texture with the expected
        // orientation. Asking libmpv to flip it again turns the video upside down.
        int flipY = 0;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &target},
            {MPV_RENDER_PARAM_FLIP_Y, &flipY},
            {MPV_RENDER_PARAM_INVALID, nullptr}
        };
        mpv_render_context_render(m_context, params);
        mpv_render_context_report_swap(m_context);
        QQuickOpenGLUtils::resetOpenGLState();
    }

private:
    static void onUpdate(void *context)
    {
        auto *renderer = static_cast<MpvRenderer *>(context);
        QMetaObject::invokeMethod(renderer->m_player, [player = renderer->m_player] { player->update(); }, Qt::QueuedConnection);
    }

    MpvPlayer *m_player = nullptr;
    mpv_render_context *m_context = nullptr;
};

MpvPlayer::MpvPlayer(QQuickItem *parent)
    : QQuickFramebufferObject(parent)
{
    setMirrorVertically(false);
    m_mpv = mpv_create();
    if (!m_mpv) {
        qWarning() << "[mpv] mpv_create 返回 null";
        QMetaObject::invokeMethod(this, [this] { emit mpvError(QStringLiteral("无法初始化 libmpv")); }, Qt::QueuedConnection);
        return;
    }
    mpv_set_option_string(m_mpv, "vo", "libmpv");
    mpv_set_option_string(m_mpv, "hwdec", "auto-safe");
    mpv_set_option_string(m_mpv, "keep-open", "yes");
    mpv_set_option_string(m_mpv, "osd-level", "0");
    mpv_set_option_string(m_mpv, "alang", "chi,zho,zh,eng,en");
    mpv_set_option_string(m_mpv, "slang", "chi,zho,zh,eng,en");
    const int initResult = mpv_initialize(m_mpv);
    if (initResult < 0) {
        qWarning() << "[mpv] mpv_initialize 失败:" << mpv_error_string(initResult);
        mpv_terminate_destroy(m_mpv);
        m_mpv = nullptr;
        QMetaObject::invokeMethod(this, [this] { emit mpvError(QStringLiteral("libmpv 初始化失败")); }, Qt::QueuedConnection);
        return;
    }

    mpv_observe_property(m_mpv, 1, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 2, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 3, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 4, "volume", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 5, "media-title", MPV_FORMAT_STRING);
    mpv_observe_property(m_mpv, 6, "track-list", MPV_FORMAT_NODE);
    mpv_observe_property(m_mpv, 7, "chapter-list", MPV_FORMAT_NODE);
    mpv_observe_property(m_mpv, 8, "cache-speed", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, 9, "video-bitrate", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 10, "audio-bitrate", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 11, "demuxer-cache-idle", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 12, "paused-for-cache", MPV_FORMAT_FLAG);
    mpv_set_wakeup_callback(m_mpv, &MpvPlayer::wakeup, this);
}

MpvPlayer::~MpvPlayer()
{
    if (m_mpv) {
        mpv_set_wakeup_callback(m_mpv, nullptr, nullptr);
        mpv_terminate_destroy(m_mpv);
    }
}

QQuickFramebufferObject::Renderer *MpvPlayer::createRenderer() const
{
    return new MpvRenderer(const_cast<MpvPlayer *>(this));
}

void MpvPlayer::wakeup(void *context)
{
    QMetaObject::invokeMethod(static_cast<MpvPlayer *>(context), &MpvPlayer::processEvents, Qt::QueuedConnection);
}

void MpvPlayer::processEvents()
{
    if (!m_mpv)
        return;
    while (mpv_event *event = mpv_wait_event(m_mpv, 0)) {
        if (event->event_id == MPV_EVENT_NONE)
            break;
        handleEvent(event);
    }
}

void MpvPlayer::handleEvent(mpv_event *event)
{
    if (event->event_id == MPV_EVENT_PROPERTY_CHANGE) {
        auto *property = static_cast<mpv_event_property *>(event->data);
        if (!property || !property->data)
            return;
        const QByteArray name(property->name);
        if (name == "pause") {
            const bool value = *static_cast<int *>(property->data) != 0;
            if (m_paused != value) { m_paused = value; emit pausedChanged(); }
        } else if (name == "time-pos") {
            m_position = *static_cast<double *>(property->data); emit positionChanged();
        } else if (name == "duration") {
            m_duration = *static_cast<double *>(property->data); emit durationChanged();
        } else if (name == "volume") {
            m_volume = *static_cast<double *>(property->data); emit volumeChanged();
        } else if (name == "media-title") {
            m_mediaTitle = QString::fromUtf8(*static_cast<char **>(property->data)); emit mediaTitleChanged();
        } else if (name == "track-list") {
            const auto *node = static_cast<mpv_node *>(property->data);
            updateTracks(nodeToVariant(*node).toList());
        } else if (name == "chapter-list") {
            const auto *node = static_cast<mpv_node *>(property->data);
            updateChapters(nodeToVariant(*node).toList());
        } else if (name == "cache-speed") {
            const qint64 rawRate = *static_cast<qint64 *>(property->data);
            m_instantLoadRate = rawRate > 0 ? static_cast<double>(rawRate) : 0.0;
            if (m_instantLoadRate > 0) {
                m_loadRateTotal += m_instantLoadRate;
                ++m_loadRateSamples;
                m_averageLoadRate = m_loadRateTotal / static_cast<double>(m_loadRateSamples);
            }
            emit loadRateChanged();
        } else if (name == "video-bitrate") {
            m_videoBitrate = qMax(0.0, *static_cast<double *>(property->data));
            emit bitrateChanged();
        } else if (name == "audio-bitrate") {
            m_audioBitrate = qMax(0.0, *static_cast<double *>(property->data));
            emit bitrateChanged();
        } else if (name == "demuxer-cache-idle") {
            m_cacheIdle = *static_cast<int *>(property->data) != 0;
            emit cacheStateChanged();
        } else if (name == "paused-for-cache") {
            m_buffering = *static_cast<int *>(property->data) != 0;
            emit cacheStateChanged();
        }
    } else if (event->event_id == MPV_EVENT_FILE_LOADED) {
        if (!m_playing) { m_playing = true; emit playingChanged(); }
    } else if (event->event_id == MPV_EVENT_END_FILE) {
        if (m_playing) { m_playing = false; emit playingChanged(); }
        emit playbackEnded();
    } else if (event->event_id == MPV_EVENT_LOG_MESSAGE) {
        auto *message = static_cast<mpv_event_log_message *>(event->data);
        if (message && message->log_level <= MPV_LOG_LEVEL_ERROR)
            emit mpvError(QString::fromUtf8(message->text).trimmed());
    }
}

void MpvPlayer::command(const QStringList &args)
{
    if (!m_mpv || args.isEmpty())
        return;
    QList<QByteArray> bytes;
    std::vector<const char *> values;
    for (const QString &arg : args)
        bytes.append(arg.toUtf8());
    for (const QByteArray &value : std::as_const(bytes))
        values.push_back(value.constData());
    values.push_back(nullptr);
    const int result = mpv_command_async(m_mpv, 0, values.data());
    if (result < 0)
        emit mpvError(QString::fromUtf8(mpv_error_string(result)));
}

void MpvPlayer::applySettings(const QString &hwdec, const QString &alang, const QString &slang)
{
    if (!m_mpv)
        return;
    // hwdec/alang/slang 均为运行时可切换属性，对后续加载的媒体生效
    mpv_set_property_string(m_mpv, "hwdec", hwdec.toUtf8().constData());
    mpv_set_property_string(m_mpv, "alang", alang.toUtf8().constData());
    mpv_set_property_string(m_mpv, "slang", slang.toUtf8().constData());
}

void MpvPlayer::setSource(const QString &source)
{
    if (m_source == source)
        return;
    m_source = source;
    emit sourceChanged();
    if (!source.isEmpty())
        play(source);
}

void MpvPlayer::play(const QString &url, double startSeconds)
{
    if (m_position != 0) {
        m_position = 0;
        emit positionChanged();
    }
    if (m_duration != 0) {
        m_duration = 0;
        emit durationChanged();
    }
    resetNetworkStats();
    m_source = url;
    emit sourceChanged();
    QStringList args{"loadfile", url, "replace"};
    if (startSeconds > 0.5) {
        // mpv 0.41 的第 4 个 loadfile 参数是播放列表索引，文件选项位于其后。
        // 省略 -1 会让 start=... 被当作整数索引解析并报“非法参数”。
        args << QStringLiteral("-1");
        args << QStringLiteral("start=%1").arg(startSeconds, 0, 'f', 3);
    }
    command(args);
}

void MpvPlayer::resetNetworkStats()
{
    m_instantLoadRate = 0;
    m_averageLoadRate = 0;
    m_loadRateTotal = 0;
    m_loadRateSamples = 0;
    m_videoBitrate = 0;
    m_audioBitrate = 0;
    m_cacheIdle = false;
    m_buffering = false;
    emit loadRateChanged();
    emit bitrateChanged();
    emit cacheStateChanged();
}

void MpvPlayer::stop()
{
    command({"stop"});
    m_source.clear();
    emit sourceChanged();
}

void MpvPlayer::setPaused(bool paused)
{
    if (!m_mpv)
        return;
    int value = paused ? 1 : 0;
    mpv_set_property_async(m_mpv, 0, "pause", MPV_FORMAT_FLAG, &value);
}

void MpvPlayer::togglePause() { command({"cycle", "pause"}); }

void MpvPlayer::setPosition(double position)
{
    command({"seek", QString::number(position, 'f', 3), "absolute+exact"});
}

void MpvPlayer::seekRelative(double seconds)
{
    command({"seek", QString::number(seconds, 'f', 3), "relative+exact"});
}

void MpvPlayer::setVolume(double volume)
{
    if (!m_mpv)
        return;
    mpv_set_property_async(m_mpv, 0, "volume", MPV_FORMAT_DOUBLE, &volume);
}

void MpvPlayer::selectAudioTrack(int id)
{
    if (!m_mpv)
        return;
    const QByteArray value = id > 0 ? QByteArray::number(id) : QByteArrayLiteral("no");
    const int result = mpv_set_property_string(m_mpv, "aid", value.constData());
    if (result < 0)
        emit mpvError(QString::fromUtf8(mpv_error_string(result)));
}

void MpvPlayer::selectSubtitleTrack(int id)
{
    if (!m_mpv)
        return;
    const QByteArray value = id > 0 ? QByteArray::number(id) : QByteArrayLiteral("no");
    const int result = mpv_set_property_string(m_mpv, "sid", value.constData());
    if (result < 0)
        emit mpvError(QString::fromUtf8(mpv_error_string(result)));
}

void MpvPlayer::updateTracks(const QVariantList &tracks)
{
    QVariantList audioTracks;
    QVariantList subtitleTracks;
    for (const QVariant &value : tracks) {
        const QVariantMap source = value.toMap();
        const QString type = source.value(QStringLiteral("type")).toString();
        if (type != QStringLiteral("audio") && type != QStringLiteral("sub"))
            continue;

        const QVariantMap track{
            {QStringLiteral("id"), source.value(QStringLiteral("id")).toInt()},
            {QStringLiteral("title"), source.value(QStringLiteral("title")).toString()},
            {QStringLiteral("language"), source.value(QStringLiteral("lang")).toString()},
            {QStringLiteral("codec"), source.value(QStringLiteral("codec")).toString()},
            {QStringLiteral("selected"), source.value(QStringLiteral("selected")).toBool()},
            {QStringLiteral("default"), source.value(QStringLiteral("default")).toBool()},
            {QStringLiteral("forced"), source.value(QStringLiteral("forced")).toBool()}
        };
        if (type == QStringLiteral("audio"))
            audioTracks.append(track);
        else
            subtitleTracks.append(track);
    }

    if (m_audioTracks == audioTracks && m_subtitleTracks == subtitleTracks)
        return;
    m_audioTracks = audioTracks;
    m_subtitleTracks = subtitleTracks;
    emit tracksChanged();
}

void MpvPlayer::updateChapters(const QVariantList &chapters)
{
    QVariantList next;
    next.reserve(chapters.size());
    for (const QVariant &value : chapters) {
        const QVariantMap source = value.toMap();
        const double time = source.value(QStringLiteral("time")).toDouble();
        if (time < 0)
            continue;
        next.append(QVariantMap{
            {QStringLiteral("time"), time},
            {QStringLiteral("title"), source.value(QStringLiteral("title")).toString()}
        });
    }
    if (m_chapters == next)
        return;
    m_chapters = next;
    emit chaptersChanged();
}
