#pragma once

#include <QMutex>
#include <QQuickFramebufferObject>
#include <QStringList>

struct mpv_handle;
struct mpv_event;

class MpvPlayer : public QQuickFramebufferObject
{
    Q_OBJECT
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(bool paused READ paused WRITE setPaused NOTIFY pausedChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(double position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(double duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(QString mediaTitle READ mediaTitle NOTIFY mediaTitleChanged)

public:
    explicit MpvPlayer(QQuickItem *parent = nullptr);
    ~MpvPlayer() override;

    Renderer *createRenderer() const override;
    QString source() const { return m_source; }
    bool paused() const { return m_paused; }
    bool playing() const { return m_playing; }
    double position() const { return m_position; }
    double duration() const { return m_duration; }
    double volume() const { return m_volume; }
    QString mediaTitle() const { return m_mediaTitle; }

    void setSource(const QString &source);
    void setPaused(bool paused);
    void setPosition(double position);
    void setVolume(double volume);

    Q_INVOKABLE void play(const QString &url, double startSeconds = 0.0);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void seekRelative(double seconds);
    Q_INVOKABLE void cycleAudio();
    Q_INVOKABLE void cycleSubtitle();

signals:
    void sourceChanged();
    void pausedChanged();
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void mediaTitleChanged();
    void playbackEnded();
    void mpvError(const QString &message);

private slots:
    void processEvents();

private:
    friend class MpvRenderer;
    static void wakeup(void *context);
    void command(const QStringList &args);
    void handleEvent(mpv_event *event);

    mpv_handle *m_mpv = nullptr;
    QString m_source;
    bool m_paused = false;
    bool m_playing = false;
    double m_position = 0;
    double m_duration = 0;
    double m_volume = 100;
    QString m_mediaTitle;
};
