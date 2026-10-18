# podkop-geo

Keeps podkop on OpenWrt pointed at VLESS servers in a chosen location, found in any of your subscriptions.

It downloads every subscription listed in `/etc/podkop-geo/secrets`, decodes gzip or base64, geolocates each host through [ip-api.com](https://ip-api.com) and writes the matching ones into `podkop.main.urltest_proxy_links`.

## Location

The location lives in `podkop_geo.conf`, edit it before installing:

```
config location 'location'
	option name 'usa'
	option country 'US'
	option region 'Texas'
	option city 'Dallas'
```

The installer copies it to `/etc/config/podkop_geo` unless that file already exists, so a reinstall keeps your router settings. Later, edit `/etc/config/podkop_geo` directly or use uci:

```sh
uci set podkop_geo.location.name='usa'      # optional regex on the link name after #, empty checks every link
uci set podkop_geo.location.country='US'    # ISO code, optional
uci set podkop_geo.location.region='Texas'  # optional, fallback when no city matches
uci set podkop_geo.location.city='Dallas'   # optional
uci commit podkop_geo && podkop-geo update
```

Matching ignores case, prefers the city, then the region, and with neither set takes the whole country. At least one of the three must be set. To check every link, run `uci delete podkop_geo.location.name`.

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

The free tier allows 45 requests per minute over plain HTTP. Every checked server uses one request, so keep the `name` filter when subscriptions are large. If the host sits behind a CDN, ip-api reports where the CDN is, not the real server.

## Install

Run these commands on your computer from the cloned repository, not on the router. `scp` copies the files to the router and `ssh` runs the installer there, so the router needs neither git nor the repository.

```sh
cp secrets.example secrets   # put your real subscription URLs here, it is gitignored
router=root@<router_ip>      # your router address, e.g. root@192.168.1.1
scp -O podkop-geo install.sh podkop_geo.conf secrets secrets.example "$router":/tmp/
ssh "$router" 'sh /tmp/install.sh && rm /tmp/secrets && podkop-geo update'
```

The installer enables the podkop mixed proxy (port 2080) for health checks and adds a cron job that runs `podkop-geo check` every five minutes.

## Use

- `podkop-geo update` switches to the configured location right now
- `podkop-geo check` probes `generate_204` through the proxy and updates on failure
- `logread -e podkop-geo` shows what was found, with the ip-api location of every candidate

## Test

```sh
bats tests/
```
