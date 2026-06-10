#include "ipSplitTunnelingController.h"
#include "core/utils/networkUtilities.h"
#include <QJsonObject>

namespace {
const QStringList kRussianBypassHosts = {
    QStringLiteral("2gis.com"),
    QStringLiteral("2gis.ru"),
    QStringLiteral("alfabank.ru"),
    QStringLiteral("api.hh.ru"),
    QStringLiteral("avito.ru"),
    QStringLiteral("avito.st"),
    QStringLiteral("avatars.mds.yandex.net"),
    QStringLiteral("wildberries.ru"),
    QStringLiteral("www.wildberries.ru"),
    QStringLiteral("wb.ru"),
    QStringLiteral("www.wb.ru"),
    QStringLiteral("static.wbstatic.net"),
    QStringLiteral("basket-01.wbbasket.ru"),
    QStringLiteral("basket-02.wbbasket.ru"),
    QStringLiteral("basket-03.wbbasket.ru"),
    QStringLiteral("basket-04.wbbasket.ru"),
    QStringLiteral("basket-05.wbbasket.ru"),
    QStringLiteral("basket-06.wbbasket.ru"),
    QStringLiteral("basket-07.wbbasket.ru"),
    QStringLiteral("basket-08.wbbasket.ru"),
    QStringLiteral("basket-09.wbbasket.ru"),
    QStringLiteral("basket-10.wbbasket.ru"),
    QStringLiteral("basket-11.wbbasket.ru"),
    QStringLiteral("basket-12.wbbasket.ru"),
    QStringLiteral("basket-13.wbbasket.ru"),
    QStringLiteral("basket-14.wbbasket.ru"),
    QStringLiteral("basket-15.wbbasket.ru"),
    QStringLiteral("beeline.ru"),
    QStringLiteral("cdn1.ozone.ru"),
    QStringLiteral("cian.ru"),
    QStringLiteral("click.alfabank.ru"),
    QStringLiteral("domclick.ru"),
    QStringLiteral("dzen.ru"),
    QStringLiteral("eda.yandex.ru"),
    QStringLiteral("gosuslugi.ru"),
    QStringLiteral("esia.gosuslugi.ru"),
    QStringLiteral("gu-st.ru"),
    QStringLiteral("hh.ru"),
    QStringLiteral("hhcdn.ru"),
    QStringLiteral("hd.kinopoisk.ru"),
    QStringLiteral("ivi.ru"),
    QStringLiteral("img.avito.st"),
    QStringLiteral("kion.ru"),
    QStringLiteral("kinopoisk.ru"),
    QStringLiteral("kuper.ru"),
    QStringLiteral("lavka.yandex.ru"),
    QStringLiteral("lk.megafon.ru"),
    QStringLiteral("login.mts.ru"),
    QStringLiteral("m.avito.ru"),
    QStringLiteral("m.vk.com"),
    QStringLiteral("mail.ru"),
    QStringLiteral("market.yandex.ru"),
    QStringLiteral("maps.2gis.com"),
    QStringLiteral("megafon.ru"),
    QStringLiteral("mironline.ru"),
    QStringLiteral("mts.ru"),
    QStringLiteral("my.mail.ru"),
    QStringLiteral("my.beeline.ru"),
    QStringLiteral("mycdn.me"),
    QStringLiteral("nspk.ru"),
    QStringLiteral("ok.ru"),
    QStringLiteral("okcdn.ru"),
    QStringLiteral("okko.tv"),
    QStringLiteral("online.sberbank.ru"),
    QStringLiteral("online.vtb.ru"),
    QStringLiteral("odnoklassniki.ru"),
    QStringLiteral("otpravka.pochta.ru"),
    QStringLiteral("ozon.ru"),
    QStringLiteral("ozone.ru"),
    QStringLiteral("ozonusercontent.com"),
    QStringLiteral("pass.rzd.ru"),
    QStringLiteral("pochta.ru"),
    QStringLiteral("pos.gosuslugi.ru"),
    QStringLiteral("privetmir.ru"),
    QStringLiteral("rzd.ru"),
    QStringLiteral("sber.ru"),
    QStringLiteral("sberbank.ru"),
    QStringLiteral("sbermarket.ru"),
    QStringLiteral("samokat.ru"),
    QStringLiteral("start.ru"),
    QStringLiteral("static.avito.ru"),
    QStringLiteral("static.mts.ru"),
    QStringLiteral("static.vk.com"),
    QStringLiteral("www.sberbank.ru"),
    QStringLiteral("t2.ru"),
    QStringLiteral("tbank.ru"),
    QStringLiteral("tele2.ru"),
    QStringLiteral("ticket.rzd.ru"),
    QStringLiteral("tinkoff.ru"),
    QStringLiteral("userapi.com"),
    QStringLiteral("vk-cdn.net"),
    QStringLiteral("vk.com"),
    QStringLiteral("vk.ru"),
    QStringLiteral("vkuseraudio.net"),
    QStringLiteral("vkvideo.ru"),
    QStringLiteral("vtb.ru"),
    QStringLiteral("wink.ru"),
    QStringLiteral("www.2gis.ru"),
    QStringLiteral("www.alfabank.ru"),
    QStringLiteral("www.avito.ru"),
    QStringLiteral("www.cian.ru"),
    QStringLiteral("www.domclick.ru"),
    QStringLiteral("www.dzen.ru"),
    QStringLiteral("www.gosuslugi.ru"),
    QStringLiteral("www.hh.ru"),
    QStringLiteral("www.ivi.ru"),
    QStringLiteral("www.kinopoisk.ru"),
    QStringLiteral("www.megafon.ru"),
    QStringLiteral("www.mironline.ru"),
    QStringLiteral("www.mts.ru"),
    QStringLiteral("www.ok.ru"),
    QStringLiteral("www.okko.tv"),
    QStringLiteral("www.odnoklassniki.ru"),
    QStringLiteral("www.ozon.ru"),
    QStringLiteral("www.pochta.ru"),
    QStringLiteral("www.rzd.ru"),
    QStringLiteral("www.sber.ru"),
    QStringLiteral("www.tbank.ru"),
    QStringLiteral("www.tinkoff.ru"),
    QStringLiteral("www.vk.com"),
    QStringLiteral("www.vtb.ru"),
    QStringLiteral("www.wink.ru"),
    QStringLiteral("ya.ru"),
    QStringLiteral("yandex.net"),
    QStringLiteral("yandex.ru"),
    QStringLiteral("yandex.st"),
    QStringLiteral("yastatic.net"),
    QStringLiteral("zen.yandex.ru")
};

const QStringList kRussianBypassSubnets = {
    QStringLiteral("176.101.88.0/24"),
    QStringLiteral("176.101.90.0/24"),
    QStringLiteral("185.138.252.0/22"),
    QStringLiteral("185.62.200.0/23"),
    QStringLiteral("185.62.202.0/24"),
    QStringLiteral("194.1.214.0/24"),
    QStringLiteral("213.184.155.0/24"),
    QStringLiteral("213.184.156.0/22"),
    QStringLiteral("85.198.76.0/22"),
    QStringLiteral("90.156.247.0/24"),
    QStringLiteral("91.230.107.0/24")
};

void addResolvedAddress(QMap<QString, QString> &excludedSubnets, const QHostAddress &address)
{
    if (address.protocol() != QAbstractSocket::NetworkLayerProtocol::IPv4Protocol) {
        return;
    }

    const QString subnet = address.toString() + QStringLiteral("/32");
    if (NetworkUtilities::checkIpSubnetFormat(subnet)) {
        excludedSubnets.insert(subnet, QString());
    }
}
}

IpSplitTunnelingController::IpSplitTunnelingController(SecureAppSettingsRepository* appSettingsRepository, QObject* parent)
    : QObject(parent),
      m_appSettingsRepository(appSettingsRepository)
{
    m_currentRouteMode = m_appSettingsRepository->routeMode();
    if (m_currentRouteMode == RouteMode::VpnAllSites) { // for old split tunneling configs
        m_appSettingsRepository->setRouteMode(RouteMode::VpnOnlyForwardSites);
        m_currentRouteMode = RouteMode::VpnOnlyForwardSites;
    }
    fillSites();
}

bool IpSplitTunnelingController::addSiteInternal(const QString &hostname, const QString &ip)
{
    QVariantMap existing = m_appSettingsRepository->vpnSites(m_currentRouteMode);
    if (existing.contains(hostname) && ip.isEmpty()) {
        return false;
    }

    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname && (m_sites[i].second.isEmpty() && !ip.isEmpty())) {
            m_sites[i].second = ip;
            m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ip);
            return true;
        } else if (m_sites[i].first == hostname && (m_sites[i].second == ip)) {
            return false;
        }
    }
    m_sites.append(qMakePair(hostname, ip));
    m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ip);
    return true;
}

void IpSplitTunnelingController::addSites(const QMap<QString, QString> &sites, bool replaceExisting)
{
    if (replaceExisting) {
        m_sites.clear();
    }
    for (auto it = sites.constBegin(); it != sites.constEnd(); ++it) {
        const QString &hostname = it.key();
        const QString &ip = it.value();
        bool found = false;
        for (int i = 0; i < m_sites.size(); i++) {
            if (m_sites[i].first == hostname) {
                if (!ip.isEmpty()) {
                    m_sites[i].second = ip;
                }
                found = true;
                break;
            }
        }
        if (!found) {
            m_sites.append(qMakePair(hostname, ip));
        }
    }
    if (replaceExisting) {
        m_appSettingsRepository->removeAllVpnSites(m_currentRouteMode);
    }
    m_appSettingsRepository->addVpnSites(m_currentRouteMode, sites);
}

bool IpSplitTunnelingController::addSite(const QString &hostname)
{
    QString normalizedHostname = normalizeHostname(hostname);
    
    if (!validateHostname(normalizedHostname)) {
        return false;
    }
    
    if (NetworkUtilities::ipAddressWithSubnetRegExp().exactMatch(normalizedHostname)) {
        processSite(normalizedHostname, "");
        return true;
    }
    
    if (addSiteInternal(normalizedHostname, "")) {
        QHostInfo::lookupHost(normalizedHostname, this, SLOT(onHostResolved(QHostInfo)));
        return true;
    }
    
    return false;
}

bool IpSplitTunnelingController::removeSite(const QString &hostname)
{
    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname) {
            m_sites.removeAt(i);
            m_appSettingsRepository->removeVpnSite(m_currentRouteMode, hostname);
            return true;
        }
    }
    return false;
}

void IpSplitTunnelingController::removeSites()
{
    m_sites.clear();
    m_appSettingsRepository->removeAllVpnSites(m_currentRouteMode);
}

void IpSplitTunnelingController::setRouteMode(RouteMode routeMode)
{
    m_currentRouteMode = routeMode;
    fillSites();
    m_appSettingsRepository->setRouteMode(routeMode);
}

void IpSplitTunnelingController::toggleSplitTunneling(bool enabled)
{
    m_appSettingsRepository->setSitesSplitTunnelingEnabled(enabled);
}

int IpSplitTunnelingController::configureRussianServicesBypass(bool enabled)
{
    m_appSettingsRepository->setRussianServicesBypassEnabled(enabled);
    setRouteMode(RouteMode::VpnAllExceptSites);
    toggleSplitTunneling(enabled);

    if (!enabled) {
        return 0;
    }

    QMap<QString, QString> excludedSubnets;
    for (const QString &subnet : kRussianBypassSubnets) {
        if (NetworkUtilities::checkIpSubnetFormat(subnet)) {
            excludedSubnets.insert(subnet, QString());
        }
    }

    for (const QString &host : kRussianBypassHosts) {
        const QHostInfo hostInfo = QHostInfo::fromName(host);
        if (hostInfo.error() != QHostInfo::NoError) {
            continue;
        }

        for (const QHostAddress &address : hostInfo.addresses()) {
            addResolvedAddress(excludedSubnets, address);
        }
    }

    if (!excludedSubnets.isEmpty()) {
        addSites(excludedSubnets, true);
    }

    return excludedSubnets.size();
}

RouteMode IpSplitTunnelingController::getRouteMode() const
{
    return m_currentRouteMode;
}

bool IpSplitTunnelingController::isSplitTunnelingEnabled() const
{
    return m_appSettingsRepository->isSitesSplitTunnelingEnabled();
}

bool IpSplitTunnelingController::isRussianServicesBypassEnabled() const
{
    return m_appSettingsRepository->isRussianServicesBypassEnabled();
}

QVector<QPair<QString, QString>> IpSplitTunnelingController::getCurrentSites() const
{
    return m_sites;
}

void IpSplitTunnelingController::fillSites()
{
    QVariantMap sitesMap = m_appSettingsRepository->vpnSites(m_currentRouteMode);
    m_sites.clear();
    for (auto it = sitesMap.begin(); it != sitesMap.end(); ++it) {
        m_sites.append(qMakePair(it.key(), it.value().toString()));
    }
}

QString IpSplitTunnelingController::normalizeHostname(const QString &hostname) const
{
    QString normalized = hostname;
    normalized.replace("https://", "");
    normalized.replace("http://", "");
    normalized.replace("ftp://", "");
    normalized = normalized.split("/", Qt::SkipEmptyParts).first();
    return normalized;
}

bool IpSplitTunnelingController::validateHostname(const QString &hostname) const
{
    if (hostname.isEmpty()) {
        return false;
    }
    if (!hostname.contains(".") && !NetworkUtilities::ipAddressWithSubnetRegExp().exactMatch(hostname)) {
        return false;
    }
    return true;
}


void IpSplitTunnelingController::onHostResolved(const QHostInfo &hostInfo)
{
    const QList<QHostAddress> &addresses = hostInfo.addresses();
    QString hostname = hostInfo.hostName();
    
    for (const QHostAddress &addr : addresses) {
        if (addr.protocol() == QAbstractSocket::NetworkLayerProtocol::IPv4Protocol) {
            processSiteAfterResolve(hostname, addr.toString());
            break;
        }
    }
}

void IpSplitTunnelingController::processSiteAfterResolve(const QString &hostname, const QString &ip)
{
    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname && m_sites[i].second.isEmpty()) {
            m_sites[i].second = ip;
            m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ip);
            break;
        }
    }
}

void IpSplitTunnelingController::processSite(const QString &hostname, const QString &ip)
{
    addSiteInternal(hostname, ip);
}

bool IpSplitTunnelingController::importSitesFromJson(const QByteArray& jsonData, bool replaceExisting, QString &errorMessage)
{
    QJsonParseError parseError;
    QJsonDocument jsonDocument = QJsonDocument::fromJson(jsonData, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        errorMessage = tr("Failed to parse JSON data: %1").arg(parseError.errorString());
        return false;
    }
    
    if (!jsonDocument.isArray()) {
        errorMessage = tr("The JSON data is not an array");
        return false;
    }
    
    QJsonArray jsonArray = jsonDocument.array();
    QMap<QString, QString> sites;
    
    for (auto jsonValue : jsonArray) {
        QJsonObject jsonObject = jsonValue.toObject();
        QString hostname = jsonObject.value("hostname").toString("");
        QString ip = jsonObject.value("ip").toString("");
        
        QString normalizedHostname = normalizeHostname(hostname);
        
        if (!validateHostname(normalizedHostname)) {
            qDebug() << normalizedHostname << " not look like ip adress or domain name";
            continue;
        }
        
        sites.insert(normalizedHostname, ip);
    }
    
    addSites(sites, replaceExisting);
    
    return true;
}

QByteArray IpSplitTunnelingController::exportSitesToJson() const
{
    QVector<QPair<QString, QString>> sites = getCurrentSites();
    QJsonArray jsonArray;
    
    for (const auto &site : sites) {
        QJsonObject jsonObject;
        jsonObject["hostname"] = site.first;
        jsonObject["ip"] = site.second;
        jsonArray.append(jsonObject);
    }
    
    QJsonDocument jsonDocument(jsonArray);
    return jsonDocument.toJson();
}
