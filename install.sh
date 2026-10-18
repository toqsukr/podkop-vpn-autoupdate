#!/bin/sh
set -e
cd "$(dirname "$0")"
for package in curl coreutils-base64; do
	command -v "${package#coreutils-}" >/dev/null || { opkg update && opkg install "$package"; }
done
cp podkop-dallas /usr/bin/podkop-dallas && chmod 755 /usr/bin/podkop-dallas
mkdir -p /etc/podkop-dallas
if [ ! -f /etc/podkop-dallas/secrets ]; then
	if [ -f secrets ]; then cp secrets /etc/podkop-dallas/secrets; else cp secrets.example /etc/podkop-dallas/secrets; fi
fi
chmod 600 /etc/podkop-dallas/secrets
grep -qx /etc/podkop-dallas/ /etc/sysupgrade.conf || echo /etc/podkop-dallas/ >>/etc/sysupgrade.conf
uci set podkop.main.mixed_proxy_enabled=1
uci set podkop.main.mixed_proxy_port="$(uci -q get podkop.main.mixed_proxy_port || echo 2080)"
uci commit podkop
/etc/init.d/podkop restart
touch /etc/crontabs/root
grep -q 'podkop-dallas check' /etc/crontabs/root || echo '*/5 * * * * /usr/bin/podkop-dallas check' >>/etc/crontabs/root
/etc/init.d/cron enable
/etc/init.d/cron restart
grep -q example.com /etc/podkop-dallas/secrets && echo "Put your subscription URLs into /etc/podkop-dallas/secrets and run podkop-dallas update"
echo "Installed podkop-dallas"
