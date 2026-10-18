#!/bin/sh
set -e
cd "$(dirname "$0")"
[ ! -f secrets ] || chmod 600 secrets
provide() {
	if command -v apk >/dev/null; then
		apk update && apk add "$1"
	else
		opkg update && opkg install "$1"
	fi
}
command -v curl >/dev/null || provide curl
command -v base64 >/dev/null || provide coreutils-base64
[ -f /etc/ssl/certs/ca-certificates.crt ] || provide ca-bundle
cp podkop-geo /usr/bin/podkop-geo && chmod 755 /usr/bin/podkop-geo
mkdir -p /etc/podkop-geo
if [ -f secrets ]; then
	cp secrets /etc/podkop-geo/secrets
elif [ ! -f /etc/podkop-geo/secrets ]; then
	cp secrets.example /etc/podkop-geo/secrets
fi
chmod 600 /etc/podkop-geo/secrets
cp podkop_geo.conf /etc/config/podkop_geo
grep -qx /etc/config/podkop_geo /etc/sysupgrade.conf || echo /etc/config/podkop_geo >>/etc/sysupgrade.conf
grep -qx /etc/podkop-geo/ /etc/sysupgrade.conf || echo /etc/podkop-geo/ >>/etc/sysupgrade.conf
if [ "$(uci -q get podkop.main.mixed_proxy_enabled)" != 1 ] || [ -z "$(uci -q get podkop.main.mixed_proxy_port)" ]; then
	uci set podkop.main.mixed_proxy_enabled=1
	uci set podkop.main.mixed_proxy_port="$(uci -q get podkop.main.mixed_proxy_port || echo 2080)"
	uci commit podkop
	/etc/init.d/podkop restart
fi
touch /etc/crontabs/root
grep -q 'podkop-geo check' /etc/crontabs/root || echo '*/5 * * * * /usr/bin/podkop-geo check' >>/etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart
if grep -q example.com /etc/podkop-geo/secrets; then echo "Put your subscription URLs into /etc/podkop-geo/secrets and run podkop-geo update"; fi
echo "Installed podkop-geo"
