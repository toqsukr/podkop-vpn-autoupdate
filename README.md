# podkop-geo

Keeps podkop on OpenWrt pointed at VLESS servers in a chosen location, found in any of your subscriptions.

Only `vless://` links are supported, see [Limitations](#limitations).

It downloads every subscription listed in `/etc/podkop-geo/secrets`, decodes gzip or base64, geolocates each host through [ip-api.com](https://ip-api.com) and writes the matching ones into `podkop.main.urltest_proxy_links`.

## Location

The location lives in `podkop_geo.conf`, edit it and run `./deploy.sh root@<router_ip>` again:

```
config location 'location'
	option name 'usa'
	option country 'US'
	option region 'Texas'
	option city 'Dallas'
```

- `name` is an optional regex on the link name after `#`, matched after URL-decoding, so `США` or `🇺🇸` work; remove the line to check every link
- `country` is an optional ISO code
- `region` is optional
- `city` is optional

Every deploy replaces `/etc/config/podkop_geo` on the router with this file and runs `podkop-geo update`.

Every option that is set must match, ignoring case, so podkop always gets servers from exactly one location and never from a neighbouring city. When nothing matches, the script fails and leaves podkop untouched. At least one of `country`, `region` and `city` must be set.

### Where the values come from

Geolocation comes from the free [ip-api.com](https://ip-api.com) API, so `country`, `region` and `city` must be spelled exactly as it reports them, in English:

| Option    | ip-api field  | Example  |
|-----------|---------------|----------|
| `country` | `countryCode` | `US`     |
| `region`  | `regionName`  | `Texas`  |
| `city`    | `city`        | `Dallas` |

To see what ip-api reports for a server, open `https://ip-api.com/#<ip or host>` in a browser, or ask it from the router:

```sh
curl "http://ip-api.com/line/<ip>?fields=countryCode,regionName,city"
```

After `podkop-geo update`, `logread -e podkop-geo` lists every checked host with the country, region and city ip-api returned for it, so you can copy the values from there.

The free tier allows 45 requests per minute over plain HTTP. Every checked server uses one request, so keep the `name` filter when subscriptions are large. Answers are cached per IP in `/tmp/podkop-geo/geo` for a day, failed lookups are retried next time. If the host sits behind a CDN, ip-api reports where the CDN is, not the real server.

## Install

Run this on your computer from the cloned repository, the router needs neither git nor the repository:

```sh
cp secrets.example secrets           # put your real subscription URLs here, it is gitignored
./deploy.sh root@<router_ip>         # e.g. ./deploy.sh root@192.168.1.1
```

`deploy.sh` copies the files to the router with `scp`, runs `install.sh` there over `ssh`, removes the uploaded secrets from `/tmp` and runs the first `podkop-geo update`. Run it again after changing the script, `secrets` or `podkop_geo.conf`: all of them are replaced on the router.

The installer enables the podkop mixed proxy (port 2080) for health checks and adds a cron job that runs `podkop-geo check` every five minutes.

## Use

- `podkop-geo update` switches to the configured location right now
- `podkop-geo check` probes `generate_204` through the proxy and updates on failure, but at most once per 30 minutes, so a dead server does not trigger a full rescan every five minutes; it refuses to run when the mixed proxy is disabled
- `logread -e podkop-geo` shows what was found, with the ip-api location of every candidate

## Limitations

- Only `vless://` links are read, `vmess://`, `trojan://`, `ss://` and others are ignored
- A host behind a CDN geolocates to the CDN, not to the real server
- Subscription URLs never reach the log, a failed download is reported by its position among the URLs in `secrets`, like `Subscription #2`

## Test

```sh
bats tests/
```
