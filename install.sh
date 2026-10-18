#!/bin/sh
set -e
cd "$(dirname "$0")"
for package in curl coreutils-base64; do
	command -v "${package#coreutils-}" >/dev/null || { opkg update && opkg install "$package"; }
done
cp podkop-geo /usr/bin/podkop-geo && chmod 755 /usr/bin/podkop-geo
mkdir -p /etc/podkop-geo
if [ ! -f /etc/podkop-geo/secrets ]; then
	if [ -f secrets ]; then cp secrets /etc/podkop-geo/secrets; else cp secrets.example /etc/podkop-geo/secrets; fi
fi
chmod 600 /etc/podkop-geo/secrets
[ -f /etc/config/podkop_geo ] || cp podkop_geo.conf /etc/config/podkop_geo
grep -qx /etc/config/podkop_geo /etc/sysupgrade.conf || echo /etc/config/podkop_geo >>/etc/sysupgrade.conf
grep -qx /etc/podkop-geo/ /etc/sysupgrade.conf || echo /etc/podkop-geo/ >>/etc/sysupgrade.conf
uci set podkop.main.mixed_proxy_enabled=1
uci set podkop.main.mixed_proxy_port="$(uci -q get podkop.main.mixed_proxy_port || echo 2080)"
uci commit podkop
/etc/init.d/podkop restart
touch /etc/crontabs/root
grep -q 'podkop-geo check' /etc/crontabs/root || echo '*/5 * * * * /usr/bin/podkop-geo check' >>/etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart
grep -q example.com /etc/podkop-geo/secrets && echo "Put your subscription URLs into /etc/podkop-geo/secrets and run podkop-geo update"
echo "Installed podkop-geo"
