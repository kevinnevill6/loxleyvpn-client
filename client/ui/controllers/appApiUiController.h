#ifndef APPAPIUICONTROLLER_H
#define APPAPIUICONTROLLER_H

#include <functional>

#include <QObject>
#include <QNetworkReply>
#include <QVariantList>
#include <QVariantMap>

class AppApiUiController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(QString deviceUuid READ deviceUuid CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY authenticatedChanged)
    Q_PROPERTY(bool mockMode READ mockMode WRITE setMockMode NOTIFY mockModeChanged)
    Q_PROPERTY(QVariantMap user READ user NOTIFY userChanged)
    Q_PROPERTY(QVariantList servers READ servers NOTIFY serversChanged)

public:
    explicit AppApiUiController(QObject *parent = nullptr);

    QString baseUrl() const;
    void setBaseUrl(const QString &baseUrl);

    QString deviceUuid() const;
    bool busy() const;
    bool authenticated() const;
    bool mockMode() const;
    void setMockMode(bool enabled);
    QVariantMap user() const;
    QVariantList servers() const;

public slots:
    void login(const QString &code, const QString &deviceUuid, const QString &deviceName, const QString &platform);
    void loginWithEmail(const QString &email, const QString &deviceUuid, const QString &deviceName, const QString &platform);
    void requestEmailCode(const QString &email, const QString &deviceUuid, const QString &deviceName, const QString &platform);
    void verifyEmailCode(const QString &email, const QString &code, const QString &deviceUuid, const QString &deviceName, const QString &platform);
    void fetchMe();
    void fetchServers();
    void fetchConfig(const QString &serverId);
    void openAccountPath(const QString &path);
    void clearSession();
    void useMockMode();
    void setOneTimeCodeAutofillActive(bool active);

signals:
    void baseUrlChanged();
    void busyChanged();
    void authenticatedChanged();
    void mockModeChanged();
    void userChanged();
    void serversChanged();

    void loginSucceeded();
    void loginFailed(const QString &message);
    void emailCodeRequested(const QString &email, const QString &message);
    void emailCodeRequestFailed(const QString &message);
    void meFetched();
    void meFailed(const QString &message);
    void serversFetched();
    void serversFailed(const QString &message);
    void configFetched(const QString &serverId, const QString &protocol, const QString &config, bool fakeConfig);
    void configFailed(const QString &serverId, const QString &message, int statusCode);
    void accountLinkFailed(const QString &message);
    void oneTimeCodeReceived(const QString &code);

private:
    using ResponseHandler = std::function<void(int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString)>;

    void sendJsonPost(const QString &path, const QJsonObject &body, bool authenticated, ResponseHandler handler);
    void sendGet(const QString &path, bool authenticated, ResponseHandler handler);
    void sendRequest(const QString &method, const QString &path, const QByteArray &body, bool authenticated, ResponseHandler handler);
    QString endpoint(const QString &path) const;
    bool ensureAuthenticated();
    void beginRequest();
    void endRequest();
    void setUserFromObject(const QJsonObject &object);
    void setServersFromArray(const QJsonArray &array);
    QString authFailureMessage(const QByteArray &body) const;
    QString errorMessage(int statusCode, QNetworkReply::NetworkError error, const QString &errorString) const;
    bool isFakeConfig(const QString &config) const;
    void restoreSession();
    void saveSession() const;
    void clearStoredSession() const;

    QString m_baseUrl;
    QString m_deviceUuid;
    QString m_token;
    QVariantMap m_user;
    QVariantList m_servers;
    int m_pendingRequests = 0;
    bool m_mockMode = false;
};

#endif // APPAPIUICONTROLLER_H
