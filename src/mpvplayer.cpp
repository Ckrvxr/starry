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
        int flipY = 1;
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
        QMetaObject::invokeMethod(this, [this] { emit mpvError(QStringLiteral("无法初始化 libmpv")); }, Qt::QueuedConnection);
        return;
    }
    mpv_set_option_string(m_mpv, "vo", "libmpv");
    mpv_set_option_string(m_mpv, "hwdec", "auto-safe");
    mpv_set_option_string(m_mpv, "keep-open", "yes");
    mpv_set_option_string(m_mpv, "osd-level", "0");
    mpv_set_option_string(m_mpv, "alang", "chi,zho,zh,eng,en");
    mpv_set_option_string(m_mpv, "slang", "chi,zho,zh,eng,en");
    if (mpv_initialize(m_mpv) < 0) {
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
    m_source = url;
    emit sourceChanged();
    QStringList args{"loadfile", url, "replace"};
    if (startSeconds > 0.5)
        args << QStringLiteral("start=%1").arg(startSeconds, 0, 'f', 3);
    command(args);
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

void MpvPlayer::cycleAudio() { command({"cycle", "audio"}); }
void MpvPlayer::cycleSubtitle() { command({"cycle", "sub"}); }
