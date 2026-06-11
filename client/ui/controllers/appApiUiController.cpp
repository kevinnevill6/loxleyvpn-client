#include "appApiUiController.h"

#include <algorithm>

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkRequest>
#include <QPointer>
#include <QRegularExpression>
#include <QSettings>
#include <QSysInfo>
#include <QUrl>
#include <QUuid>

#include "amneziaApplication.h"
#include "version.h"

#if defined(Q_OS_IOS)
extern "C" void loxley_setOneTimeCodeAutofillActive(bool active);
extern "C" void loxley_setOneTimeCodeAutofillHandler(void (*handler)(const char *code));

QPointer<AppApiUiController> g_loxleyAppApiController;

void loxley_handleOneTimeCodeAutofill(const char *code)
{
    const QString codeText = QString::fromUtf8(code).trimmed();
    if (codeText.isEmpty()) {
        return;
    }

    QMetaObject::invokeMethod(qApp, [codeText]() {
        if (g_loxleyAppApiController) {
            emit g_loxleyAppApiController->oneTimeCodeReceived(codeText);
        }
    }, Qt::QueuedConnection);
}
#endif

#ifndef LOXLEY_APP_API_BASE_URL
#define LOXLEY_APP_API_BASE_URL "https://staging.loxleyvpn.ru"
#endif

namespace
{
    constexpr int kRequestTimeoutMs = 10000;

    QString normalizedBaseUrl(QString value)
    {
        value = value.trimmed();
        while (value.endsWith('/')) {
            value.chop(1);
        }

        return value;
    }

    QJsonObject objectFromBody(const QByteArray &body)
    {
        const QJsonDocument doc = QJsonDocument::fromJson(body);
        return doc.isObject() ? doc.object() : QJsonObject {};
    }

    bool isEmailLike(const QString &email)
    {
        static const QRegularExpression pattern(QStringLiteral(R"(^[^\s@]+@[^\s@]+\.[^\s@]+$)"));
        return email.size() >= 6 && email.size() <= 320 && pattern.match(email).hasMatch();
    }

    QString deviceLimitMessage(const QJsonObject &payload)
    {
        const int limit = payload.value("device_limit").toInt();
        if (limit > 0) {
            return QObject::tr("Лимит устройств исчерпан. Ваш тариф позволяет %1 устройство(а). Отвяжите старое устройство или измените тариф.")
                .arg(limit);
        }

        return QObject::tr("Лимит устройств исчерпан. Отвяжите старое устройство или измените тариф.");
    }

    QString stableDeviceUuid()
    {
        QSettings settings;
        const QString key = QStringLiteral("loxley/appApiDeviceUuid");
        QString uuid = settings.value(key).toString().trimmed();
        if (uuid.isEmpty()) {
            uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
            settings.setValue(key, uuid);
            settings.sync();
        }

        return uuid;
    }
}

AppApiUiController::AppApiUiController(QObject *parent)
    : QObject(parent),
      m_baseUrl(normalizedBaseUrl(QStringLiteral(LOXLEY_APP_API_BASE_URL))),
      m_deviceUuid(stableDeviceUuid())
{
#if defined(Q_OS_IOS)
    g_loxleyAppApiController = this;
    loxley_setOneTimeCodeAutofillHandler(loxley_handleOneTimeCodeAutofill);
    connect(this, &QObject::destroyed, this, []() {
        g_loxleyAppApiController = nullptr;
        loxley_setOneTimeCodeAutofillHandler(nullptr);
    });
#endif
}

QString AppApiUiController::baseUrl() const
{
    return m_baseUrl;
}

void AppApiUiController::setBaseUrl(const QString &baseUrl)
{
    const QString normalized = normalizedBaseUrl(baseUrl);
    if (m_baseUrl == normalized) {
        return;
    }

    m_baseUrl = normalized;
    emit baseUrlChanged();
}

QString AppApiUiController::deviceUuid() const
{
    return m_deviceUuid;
}

bool AppApiUiController::busy() const
{
    return m_pendingRequests > 0;
}

bool AppApiUiController::authenticated() const
{
    return !m_token.isEmpty();
}

bool AppApiUiController::mockMode() const
{
    return m_mockMode;
}

void AppApiUiController::setMockMode(bool enabled)
{
    if (m_mockMode == enabled) {
        return;
    }

    m_mockMode = enabled;
    emit mockModeChanged();
}

QVariantMap AppApiUiController::user() const
{
    return m_user;
}

QVariantList AppApiUiController::servers() const
{
    return m_servers;
}

void AppApiUiController::login(const QString &code, const QString &deviceUuid, const QString &deviceName, const QString &platform)
{
    const QString trimmedCode = code.trimmed();
    if (trimmedCode.isEmpty()) {
        emit loginFailed(tr("Введите код доступа"));
        return;
    }

    QJsonObject body;
    body["code"] = trimmedCode;
    body["device_uuid"] = deviceUuid.trimmed().isEmpty() ? m_deviceUuid : deviceUuid.trimmed();
    body["device_name"] = deviceName.trimmed().isEmpty() ? QSysInfo::prettyProductName() : deviceName.trimmed();
    body["platform"] = platform.trimmed().isEmpty() ? QStringLiteral("android") : platform.trimmed();
    body["app_version"] = QStringLiteral(APP_VERSION);

    sendJsonPost(QStringLiteral("/api/app/auth/code"), body, false,
                 [this](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            emit loginFailed(errorMessage(statusCode, error, errorString));
            return;
        }

        const QJsonObject payload = objectFromBody(body);
        const QString token = payload.value("token").toString();
        const QJsonObject user = payload.value("user").toObject();

        if (token.isEmpty() || user.isEmpty()) {
            emit loginFailed(tr("Backend вернул неполный ответ"));
            return;
        }

        const bool wasAuthenticated = authenticated();
        m_token = token;
        setUserFromObject(user);
        setMockMode(false);

        if (!wasAuthenticated) {
            emit authenticatedChanged();
        }

        emit loginSucceeded();
    });
}

void AppApiUiController::loginWithEmail(const QString &email, const QString &deviceUuid, const QString &deviceName, const QString &platform)
{
    requestEmailCode(email, deviceUuid, deviceName, platform);
}

void AppApiUiController::requestEmailCode(const QString &email, const QString &deviceUuid, const QString &deviceName, const QString &platform)
{
    const QString trimmedEmail = email.trimmed().toLower();
    if (!isEmailLike(trimmedEmail)) {
        emit emailCodeRequestFailed(tr("Введите email"));
        return;
    }

    QJsonObject body;
    body["email"] = trimmedEmail;
    body["device_uuid"] = deviceUuid.trimmed().isEmpty() ? m_deviceUuid : deviceUuid.trimmed();
    body["device_name"] = deviceName.trimmed().isEmpty() ? QSysInfo::prettyProductName() : deviceName.trimmed();
    body["platform"] = platform.trimmed().isEmpty() ? QStringLiteral("android") : platform.trimmed();
    body["app_version"] = QStringLiteral(APP_VERSION);

    sendJsonPost(QStringLiteral("/api/app/auth/email/request-code"), body, false,
                 [this](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            const QJsonObject payload = objectFromBody(body);
            const QString message = payload.value("message").toString(errorMessage(statusCode, error, errorString));
            emit emailCodeRequestFailed(message);
            return;
        }

        const QJsonObject payload = objectFromBody(body);
        emit emailCodeRequested(payload.value("email").toString(), payload.value("message").toString());
    });
}

void AppApiUiController::verifyEmailCode(const QString &email, const QString &code, const QString &deviceUuid, const QString &deviceName, const QString &platform)
{
    const QString trimmedEmail = email.trimmed().toLower();
    const QString trimmedCode = code.trimmed();
    if (!isEmailLike(trimmedEmail)) {
        emit loginFailed(tr("Введите email"));
        return;
    }
    if (trimmedCode.isEmpty()) {
        emit loginFailed(tr("Введите код"));
        return;
    }

    QJsonObject body;
    body["email"] = trimmedEmail;
    body["code"] = trimmedCode;
    body["device_uuid"] = deviceUuid.trimmed().isEmpty() ? m_deviceUuid : deviceUuid.trimmed();
    body["device_name"] = deviceName.trimmed().isEmpty() ? QSysInfo::prettyProductName() : deviceName.trimmed();
    body["platform"] = platform.trimmed().isEmpty() ? QStringLiteral("android") : platform.trimmed();
    body["app_version"] = QStringLiteral(APP_VERSION);

    sendJsonPost(QStringLiteral("/api/app/auth/email/verify-code"), body, false,
                 [this](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            const QJsonObject payload = objectFromBody(body);
            const QString errorCode = payload.value("error").toString();
            const QString message = errorCode == QLatin1String("device_limit_exceeded")
                ? deviceLimitMessage(payload)
                : payload.value("message").toString(errorMessage(statusCode, error, errorString));
            const QJsonObject user = payload.value("user").toObject();
            if (!user.isEmpty()) {
                setUserFromObject(user);
            }
            emit loginFailed(message);
            return;
        }

        const QJsonObject payload = objectFromBody(body);
        const QString token = payload.value("token").toString();
        const QJsonObject user = payload.value("user").toObject();

        if (token.isEmpty() || user.isEmpty()) {
            emit loginFailed(tr("Backend вернул неполный ответ"));
            return;
        }

        const bool wasAuthenticated = authenticated();
        m_token = token;
        setUserFromObject(user);
        setMockMode(false);

        if (!wasAuthenticated) {
            emit authenticatedChanged();
        }

        emit loginSucceeded();
    });
}

void AppApiUiController::fetchMe()
{
    if (!ensureAuthenticated()) {
        emit meFailed(tr("Нужно войти заново"));
        return;
    }

    sendGet(QStringLiteral("/api/app/me"), true,
            [this](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            const QString message = objectFromBody(body).value("message").toString(errorMessage(statusCode, error, errorString));
            emit meFailed(message);
            return;
        }

        const QJsonObject user = objectFromBody(body).value("user").toObject();
        if (user.isEmpty()) {
            emit meFailed(tr("Backend не вернул данные подписки"));
            return;
        }

        setUserFromObject(user);
        emit meFetched();
    });
}

void AppApiUiController::fetchServers()
{
    if (!ensureAuthenticated()) {
        emit serversFailed(tr("Нужно войти заново"));
        return;
    }

    sendGet(QStringLiteral("/api/app/servers"), true,
            [this](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            const QJsonObject payload = objectFromBody(body);
            const QString message = payload.value("message").toString(errorMessage(statusCode, error, errorString));
            const QJsonObject user = payload.value("user").toObject();
            if (!user.isEmpty()) {
                setUserFromObject(user);
            }
            emit serversFailed(message);
            return;
        }

        const QJsonDocument doc = QJsonDocument::fromJson(body);
        if (!doc.isArray()) {
            emit serversFailed(tr("Backend не вернул список серверов"));
            return;
        }

        setServersFromArray(doc.array());
        emit serversFetched();
    });
}

void AppApiUiController::fetchConfig(const QString &serverId)
{
    if (!ensureAuthenticated()) {
        emit configFailed(serverId, tr("Нужно войти заново"), 401);
        return;
    }

    const QString trimmedServerId = serverId.trimmed();
    if (trimmedServerId.isEmpty()) {
        emit configFailed(serverId, tr("Сервер не выбран"), 0);
        return;
    }

    const QString path = QStringLiteral("/api/app/servers/%1/config")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(trimmedServerId)));

    sendGet(path, true,
            [this, trimmedServerId](int statusCode, const QByteArray &body, QNetworkReply::NetworkError error, const QString &errorString) {
        if (error != QNetworkReply::NoError || statusCode != 200) {
            const QJsonObject payload = objectFromBody(body);
            const QString errorCode = payload.value("error").toString();
            const QString message = errorCode == QLatin1String("device_limit_exceeded")
                ? deviceLimitMessage(payload)
                : payload.value("message").toString(errorMessage(statusCode, error, errorString));
            emit configFailed(trimmedServerId, message, statusCode);
            return;
        }

        const QJsonObject payload = objectFromBody(body);
        const QString protocol = payload.value("protocol").toString();
        const QString config = payload.value("config").toString();

        if (protocol.isEmpty() || config.isEmpty()) {
            emit configFailed(trimmedServerId, tr("Backend не вернул config"), statusCode);
            return;
        }

        emit configFetched(trimmedServerId, protocol, config, isFakeConfig(config));
    });
}

void AppApiUiController::clearSession()
{
    const bool wasAuthenticated = authenticated();
    m_token.clear();
    m_user.clear();
    m_servers.clear();

    if (wasAuthenticated) {
        emit authenticatedChanged();
    }
    emit userChanged();
    emit serversChanged();
}

void AppApiUiController::useMockMode()
{
    clearSession();
    setMockMode(true);
}

void AppApiUiController::setOneTimeCodeAutofillActive(bool active)
{
#if defined(Q_OS_IOS)
    loxley_setOneTimeCodeAutofillActive(active);
#else
    Q_UNUSED(active);
#endif
}

void AppApiUiController::sendJsonPost(const QString &path, const QJsonObject &body, bool authenticated, ResponseHandler handler)
{
    sendRequest(QStringLiteral("POST"), path, QJsonDocument(body).toJson(QJsonDocument::Compact), authenticated, std::move(handler));
}

void AppApiUiController::sendGet(const QString &path, bool authenticated, ResponseHandler handler)
{
    sendRequest(QStringLiteral("GET"), path, {}, authenticated, std::move(handler));
}

void AppApiUiController::sendRequest(const QString &method, const QString &path, const QByteArray &body, bool authenticated, ResponseHandler handler)
{
    const QUrl url(endpoint(path));
    if (!url.isValid() || url.scheme().isEmpty() || url.host().isEmpty()) {
        handler(0, {}, QNetworkReply::UnknownNetworkError, tr("Некорректный backend URL"));
        return;
    }

    QNetworkRequest request(url);
    request.setTransferTimeout(kRequestTimeoutMs);
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));

    if (authenticated) {
        request.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    }

    beginRequest();

    QNetworkReply *reply = nullptr;
    if (method == QLatin1String("POST")) {
        reply = amnApp->networkManager()->post(request, body);
    } else {
        reply = amnApp->networkManager()->get(request);
    }

    connect(reply, &QNetworkReply::finished, this, [this, reply, handler = std::move(handler)]() mutable {
        const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QNetworkReply::NetworkError error = reply->error();
        const QString errorString = reply->errorString();
        const QByteArray responseBody = reply->readAll();
        reply->deleteLater();
        endRequest();
        handler(statusCode, responseBody, error, errorString);
    });
}

QString AppApiUiController::endpoint(const QString &path) const
{
    return normalizedBaseUrl(m_baseUrl) + path;
}

bool AppApiUiController::ensureAuthenticated()
{
    return !m_token.isEmpty();
}

void AppApiUiController::beginRequest()
{
    const bool wasBusy = busy();
    ++m_pendingRequests;
    if (!wasBusy) {
        emit busyChanged();
    }
}

void AppApiUiController::endRequest()
{
    const bool wasBusy = busy();
    m_pendingRequests = std::max(0, m_pendingRequests - 1);
    if (wasBusy != busy()) {
        emit busyChanged();
    }
}

void AppApiUiController::setUserFromObject(const QJsonObject &object)
{
    m_user = object.toVariantMap();
    emit userChanged();
}

void AppApiUiController::setServersFromArray(const QJsonArray &array)
{
    QVariantList servers;
    for (const QJsonValue &value : array) {
        if (value.isObject()) {
            servers.append(value.toObject().toVariantMap());
        }
    }

    m_servers = servers;
    emit serversChanged();
}

QString AppApiUiController::errorMessage(int statusCode, QNetworkReply::NetworkError error, const QString &errorString) const
{
    if (error != QNetworkReply::NoError) {
        return tr("Backend недоступен: %1").arg(errorString);
    }

    if (statusCode == 401) {
        return tr("Код не принят backend");
    }

    if (statusCode == 404) {
        return tr("App API выключен или endpoint недоступен");
    }

    if (statusCode == 501) {
        return tr("Резервный протокол пока не включён");
    }

    if (statusCode >= 500) {
        return tr("Backend вернул ошибку");
    }

    return tr("Не удалось выполнить запрос");
}

bool AppApiUiController::isFakeConfig(const QString &config) const
{
    return config.contains(QStringLiteral("TEST_ONLY_FAKE"), Qt::CaseInsensitive)
        || config.contains(QStringLiteral("DO_NOT_USE"), Qt::CaseInsensitive)
        || config.contains(QStringLiteral("example.invalid"), Qt::CaseInsensitive);
}
