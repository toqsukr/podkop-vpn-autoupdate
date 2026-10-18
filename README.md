# podkop-dallas

Keeps podkop on OpenWrt pointed at the USA Dallas VLESS server found in any of your subscriptions.

It downloads every subscription listed in `/etc/podkop-dallas/secrets`, decodes gzip or base64, keeps `vless://` links named USA, geolocates each host through ip-api.com and writes the Dallas ones (Texas as a fallback) into `podkop.main.urltest_proxy_links`.

## Install

```sh
cp secrets.example secrets   # put your real subscription URLs here, it is gitignored
scp -O podkop-dallas install.sh secrets secrets.example root@192.168.1.1:/tmp/
ssh root@192.168.1.1 'sh /tmp/install.sh && rm /tmp/secrets && podkop-dallas update'
```

The installer enables the podkop mixed proxy (port 2080) for health checks and adds a cron job that runs `podkop-dallas check` every five minutes.

## Use

- `podkop-dallas update` switches to Dallas right now
- `podkop-dallas check` probes `generate_204` through the proxy and updates on failure
- `logread -e podkop-dallas` shows what was found, with the city of every USA candidate

## Test

```sh
bats tests/
```
