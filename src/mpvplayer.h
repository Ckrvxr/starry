#pragma once

#include <QMutex>
#include <QQuickFramebufferObject>
#include <QStringList>
#include <QVariantList>

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
    Q_PROPERTY(QVariantList audioTracks READ audioTracks NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList subtitleTracks READ subtitleTracks NOTIFY tracksChanged)
    Q_PROPERTY(QVariantList chapters READ chapters NOTIFY chaptersChanged)
    Q_PROPERTY(double instantLoadRate READ instantLoadRate NOTIFY loadRateChanged)
    Q_PROPERTY(double averageLoadRate READ averageLoadRate NOTIFY loadRateChanged)
    Q_PROPERTY(double videoBitrate READ videoBitrate NOTIFY bitrateChanged)
    Q_PROPERTY(double audioBitrate READ audioBitrate NOTIFY bitrateChanged)
    Q_PROPERTY(bool cacheIdle READ cacheIdle NOTIFY cacheStateChanged)
    Q_PROPERTY(bool buffering READ buffering NOTIFY cacheStateChanged)

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
    QVariantList audioTracks() const { return m_audioTracks; }
    QVariantList subtitleTracks() const { return m_subtitleTracks; }
    QVariantList chapters() const { return m_chapters; }
    double instantLoadRate() const { return m_instantLoadRate; }
    double averageLoadRate() const { return m_averageLoadRate; }
    double videoBitrate() const { return m_videoBitrate; }
    double audioBitrate() const { return m_audioBitrate; }
    bool cacheIdle() const { return m_cacheIdle; }
    bool buffering() const { return m_buffering; }

    void setSource(const QString &source);
    void setPaused(bool paused);
    void setPosition(double position);
    void setVolume(double volume);

    Q_INVOKABLE void play(const QString &url, double startSeconds = 0.0);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void togglePause();
    Q_INVOKABLE void seekRelative(double seconds);
    Q_INVOKABLE void selectAudioTrack(int id);
    Q_INVOKABLE void selectSubtitleTrack(int id);
    Q_INVOKABLE void applySettings(const QString &hwdec, const QString &alang, const QString &slang);

signals:
    void sourceChanged();
    void pausedChanged();
    void playingChanged();
    void positionChanged();
    void durationChanged();
    void volumeChanged();
    void mediaTitleChanged();
    void tracksChanged();
    void chaptersChanged();
    void loadRateChanged();
    void bitrateChanged();
    void cacheStateChanged();
    void playbackEnded();
    void mpvError(const QString &message);

private slots:
    void processEvents();

private:
    friend class MpvRenderer;
    static void wakeup(void *context);
    void command(const QStringList &args);
    void handleEvent(mpv_event *event);
    void updateTracks(const QVariantList &tracks);
    void updateChapters(const QVariantList &chapters);
    void resetNetworkStats();

    mpv_handle *m_mpv = nullptr;
    QString m_source;
    bool m_paused = false;
    bool m_playing = false;
    double m_position = 0;
    double m_duration = 0;
    double m_volume = 100;
    QString m_mediaTitle;
    QVariantList m_audioTracks;
    QVariantList m_subtitleTracks;
    QVariantList m_chapters;
    double m_instantLoadRate = 0;
    double m_averageLoadRate = 0;
    double m_loadRateTotal = 0;
    quint64 m_loadRateSamples = 0;
    double m_videoBitrate = 0;
    double m_audioBitrate = 0;
    bool m_cacheIdle = false;
    bool m_buffering = false;
};
