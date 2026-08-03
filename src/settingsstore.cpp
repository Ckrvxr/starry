#include "settingsstore.h"

#include <QDir>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>

namespace {

QSqlDatabase settingsDb()
{
    QSqlDatabase db = QSqlDatabase::database(QStringLiteral("settings"), /* open= */ false);
    if (!db.isValid()) {
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        QDir().mkpath(dir);
        db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("settings"));
        db.setDatabaseName(dir + QStringLiteral("/starry.db"));
        if (!db.open()) {
            qWarning() << "设置库打开失败:" << db.lastError().text();
            return {};
        }
        QSqlQuery query(db);
        query.exec(QStringLiteral("PRAGMA journal_mode = WAL"));
        query.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS settings ("
                                  "key TEXT PRIMARY KEY, value TEXT NOT NULL)"));
    }
    return db;
}

} // namespace

SettingsStore::SettingsStore(QObject *parent)
    : QObject(parent)
{
    m_hwdec = load(QStringLiteral("hwdec"), QStringLiteral("auto-safe"));
    m_alang = load(QStringLiteral("alang"), QStringLiteral("chi,zho,zh,eng,en"));
    m_slang = load(QStringLiteral("slang"), QStringLiteral("chi,zho,zh,eng,en"));
}

QString SettingsStore::load(const QString &key, const QString &defaultValue) const
{
    QSqlDatabase db = settingsDb();
    if (!db.isValid())
        return defaultValue;
    QSqlQuery query(db);
    query.prepare(QStringLiteral("SELECT value FROM settings WHERE key = ?"));
    query.addBindValue(key);
    if (!query.exec() || !query.next())
        return defaultValue;
    return query.value(0).toString();
}

void SettingsStore::save(const QString &key, const QString &value) const
{
    QSqlDatabase db = settingsDb();
    if (!db.isValid())
        return;
    QSqlQuery query(db);
    query.prepare(QStringLiteral("INSERT INTO settings(key, value) VALUES(?, ?) "
                                 "ON CONFLICT(key) DO UPDATE SET value = excluded.value"));
    query.addBindValue(key);
    query.addBindValue(value);
    query.exec();
}

void SettingsStore::setHwdec(const QString &value)
{
    if (m_hwdec == value)
        return;
    m_hwdec = value;
    save(QStringLiteral("hwdec"), value);
    emit hwdecChanged();
}

void SettingsStore::setAlang(const QString &value)
{
    if (m_alang == value)
        return;
    m_alang = value;
    save(QStringLiteral("alang"), value);
    emit alangChanged();
}

void SettingsStore::setSlang(const QString &value)
{
    if (m_slang == value)
        return;
    m_slang = value;
    save(QStringLiteral("slang"), value);
    emit slangChanged();
}
