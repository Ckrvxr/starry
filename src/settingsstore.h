#pragma once

#include <QObject>
#include <QString>

// 应用设置的 SQLite 持久化存储（settings 表，key-value）。
// 作为 QML context property `settings` 暴露。
class SettingsStore final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString hwdec READ hwdec WRITE setHwdec NOTIFY hwdecChanged)
    Q_PROPERTY(QString alang READ alang WRITE setAlang NOTIFY alangChanged)
    Q_PROPERTY(QString slang READ slang WRITE setSlang NOTIFY slangChanged)
    Q_PROPERTY(QString mpvConfig READ mpvConfig WRITE setMpvConfig NOTIFY mpvConfigChanged)
    Q_PROPERTY(QString defaultMpvConfig READ defaultMpvConfig CONSTANT)

public:
    explicit SettingsStore(QObject *parent = nullptr);

    QString hwdec() const { return m_hwdec; }
    QString alang() const { return m_alang; }
    QString slang() const { return m_slang; }
    QString mpvConfig() const { return m_mpvConfig; }
    QString defaultMpvConfig() const;

    void setHwdec(const QString &value);
    void setAlang(const QString &value);
    void setSlang(const QString &value);
    void setMpvConfig(const QString &value);

signals:
    void hwdecChanged();
    void alangChanged();
    void slangChanged();
    void mpvConfigChanged();

private:
    QString load(const QString &key, const QString &defaultValue) const;
    void save(const QString &key, const QString &value) const;

    QString m_hwdec;
    QString m_alang;
    QString m_slang;
    QString m_mpvConfig;
};
