load helper

@test "picks dallas server from plain subscription" {
	dir=$(fixture)
	host="d$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.1.2.3 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.1.2.3}" ] || { echo "dallas link was not written to podkop"; false; }
}

@test "decodes base64 subscription" {
	dir=$(fixture)
	host="b$RANDOM.example"
	dallas=$(link "$host" "%F0%9F%87%BA%F0%9F%87%B8%20USA")
	server "$dir" "$host" 10.4.5.6 US Texas Dallas
	echo "$dallas" | base64 | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.4.5.6}" ] || { echo "base64 subscription was not decoded"; false; }
}

@test "decodes urlsafe base64 without padding" {
	dir=$(fixture)
	host="u$RANDOM.example"
	dallas="$(link "$host" "USA")&x=??>>"
	server "$dir" "$host" 10.7.8.9 US Texas Dallas
	printf '%s\n' "$dallas" | base64 | tr '/+' '_-' | tr -d '=' | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.7.8.9}" ] || { echo "urlsafe base64 was not decoded"; false; }
}

@test "decompresses gzip subscription" {
	dir=$(fixture)
	host="g$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.3.3.3 US Texas Dallas
	echo "$dallas" | gzip | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.3.3.3}" ] || { echo "gzip subscription was not decompressed"; false; }
}

@test "finds dallas in second subscription" {
	dir=$(fixture)
	link "nl$RANDOM.example" "Netherlands" | subscription "$dir" a
	host="s$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.2.2.2 US Texas Dallas
	echo "$dallas" | subscription "$dir" b
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.2.2.2}" ] || { echo "dallas from second subscription was not found"; false; }
}

@test "skips usa server outside dallas" {
	dir=$(fixture)
	{ link ny.example "USA"; link dl.example "USA"; } | subscription "$dir" a
	server "$dir" ny.example 10.9.9.1 US "New York" "New York"
	server "$dir" dl.example 10.9.9.2 US Texas Dallas
	tool "$dir" update
	[ "$(links "$dir" | grep -c @10.9.9.1:)" = 0 ] || { echo "new york server was not skipped"; false; }
}

@test "rejects texas server outside dallas" {
	dir=$(fixture)
	host="t$RANDOM.example"
	server "$dir" "$host" 10.6.6.6 US Texas Irving
	link "$host" "USA" | subscription "$dir" a
	run tool "$dir" update
	[ "$status" -ne 0 ] || { echo "server outside configured city was accepted"; false; }
}

@test "keeps config when dallas is missing" {
	dir=$(fixture)
	echo "podkop.main.urltest_proxy_links=vless://old@keep.example:443#Old" >>"$dir/uci"
	link "la$RANDOM.example" "USA" | subscription "$dir" a
	tool "$dir" update || true
	[ "$(links "$dir")" = "vless://old@keep.example:443#Old" ] || { echo "config was changed without dallas"; false; }
}

@test "fails when dallas is missing" {
	dir=$(fixture)
	link "la$RANDOM.example" "USA" | subscription "$dir" a
	run tool "$dir" update
	[ "$status" -ne 0 ] || { echo "missing dallas did not fail"; false; }
}

@test "survives broken subscription" {
	dir=$(fixture)
	echo "https://sub.test/missing" >>"$dir/secrets"
	host="r$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.5.5.5 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.5.5.5}" ] || { echo "broken subscription stopped the update"; false; }
}

@test "dont restart podkop when servers are unchanged" {
	dir=$(fixture)
	host="c$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.8.8.8 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	echo "podkop.main.urltest_proxy_links=${dallas/@$host/@10.8.8.8}" >>"$dir/uci"
	tool "$dir" update
	[ ! -f "$dir/restarts" ] || { echo "podkop was restarted needlessly"; false; }
}

@test "check does nothing when proxy is alive" {
	dir=$(fixture)
	host="a$RANDOM.example"
	server "$dir" "$host" 10.0.0.7 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" check
	[ ! -f "$dir/restarts" ] || { echo "alive proxy triggered an update"; false; }
}

@test "check updates when proxy is dead" {
	dir=$(fixture)
	echo 000 >"$dir/probe"
	host="x$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.0.0.8 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" check
	[ "$(links "$dir")" = "${dallas/@$host/@10.0.0.8}" ] || { echo "dead proxy did not trigger an update"; false; }
}

@test "resolves hosts through podkop bootstrap dns" {
	dir=$(fixture)
	resolver="10.$((RANDOM % 250)).$((RANDOM % 250)).53"
	echo "podkop.settings.bootstrap_dns_server=$resolver" >>"$dir/uci"
	host="n$RANDOM.example"
	server "$dir" "$host" 10.0.1.1 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(sort -u "$dir/resolvers")" = "$resolver" ] || { echo "bootstrap dns from podkop was not used"; false; }
}

@test "picks city from location config" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.city Miami
	setting "$dir" podkop_geo.location.region Florida
	{ link dl.example "USA"; link mi.example "USA"; } | subscription "$dir" a
	server "$dir" dl.example 10.7.0.1 US Texas Dallas
	server "$dir" mi.example 10.7.0.2 US Florida Miami
	tool "$dir" update
	[ "$(links "$dir" | grep -c @10.7.0.2:)" = 1 ] || { echo "configured city was not picked"; false; }
}

@test "matches city ignoring case" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.city dALLas
	host="i$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.7.1.1 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.7.1.1}" ] || { echo "city case was not ignored"; false; }
}

@test "rejects city in other country" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.country DE
	host="w$RANDOM.example"
	link "$host" "USA" | subscription "$dir" a
	server "$dir" "$host" 10.7.2.2 US Texas Dallas
	run tool "$dir" update
	[ "$status" -ne 0 ] || { echo "server outside configured country was accepted"; false; }
}

@test "uses country alone when city and region are empty" {
	dir=$(fixture)
	printf 'podkop_geo.location.country=NL\n' >"$dir/uci"
	host="a$RANDOM.example"
	amsterdam=$(link "$host" "Netherlands")
	server "$dir" "$host" 10.7.3.3 NL "North Holland" Amsterdam
	echo "$amsterdam" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${amsterdam/@$host/@10.7.3.3}" ] || { echo "country alone did not select a server"; false; }
}

@test "checks every link when name filter is empty" {
	dir=$(fixture)
	printf 'podkop_geo.location.city=Dallas\n' >"$dir/uci"
	host="q$RANDOM.example"
	dallas=$(link "$host" "Premium-$RANDOM")
	server "$dir" "$host" 10.7.4.4 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.7.4.4}" ] || { echo "unnamed link was not checked"; false; }
}

@test "fails when location is not configured" {
	dir=$(fixture)
	: >"$dir/uci"
	host="z$RANDOM.example"
	server "$dir" "$host" 10.7.5.5 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	run tool "$dir" update
	[ "$status" -ne 0 ] || { echo "missing location did not fail"; false; }
}

@test "dont log subscription url" {
	dir=$(fixture)
	token="tok$RANDOM$RANDOM"
	echo "https://sub.test/sub/$token" >>"$dir/secrets"
	host="l$RANDOM.example"
	server "$dir" "$host" 10.8.1.1 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(grep -c "$token" "$dir/log")" = 0 ] || { echo "subscription token leaked into the log"; false; }
}

@test "refuses update while another one runs" {
	dir=$(fixture)
	echo $$ >"$dir/lock.pid"
	host="k$RANDOM.example"
	server "$dir" "$host" 10.8.2.2 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	run tool "$dir" update
	[ "$status" -ne 0 ] || { echo "concurrent update was not refused"; false; }
}

@test "ignores lock left by dead process" {
	dir=$(fixture)
	sh -c 'exit 0' &
	dead=$!
	wait "$dead"
	echo "$dead" >"$dir/lock.pid"
	host="j$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.8.3.3 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.8.3.3}" ] || { echo "stale lock blocked the update"; false; }
}

@test "reuses cached geolocation" {
	dir=$(fixture)
	host="h$RANDOM.example"
	server "$dir" "$host" 10.8.4.4 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	tool "$dir" update
	[ "$(wc -l <"$dir/geocalls" | tr -d ' ')" = 1 ] || { echo "geolocation was requested again despite cache"; false; }
}

@test "dont cache failed geolocation" {
	dir=$(fixture)
	host="f$RANDOM.example"
	echo "Address: 10.8.5.5" >"$dir/dns/$host"
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update || true
	tool "$dir" update || true
	[ "$(wc -l <"$dir/geocalls" | tr -d ' ')" = 2 ] || { echo "failed geolocation was cached"; false; }
}

@test "check pauses after recent update" {
	dir=$(fixture)
	echo 000 >"$dir/probe"
	mkdir -p "$dir/state"
	touch "$dir/state/updated"
	host="p$RANDOM.example"
	server "$dir" "$host" 10.8.6.6 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" check || true
	[ -z "$(links "$dir")" ] || { echo "check updated right after previous update"; false; }
}

@test "manual update ignores pause" {
	dir=$(fixture)
	mkdir -p "$dir/state"
	touch "$dir/state/updated"
	host="m$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.8.7.7 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.8.7.7}" ] || { echo "manual update was paused"; false; }
}

@test "matches cyrillic name in encoded fragment" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.name "США"
	host="y$RANDOM.example"
	dallas=$(link "$host" "%F0%9F%87%BA%F0%9F%87%B8%20%D0%A1%D0%A8%D0%90")
	server "$dir" "$host" 10.8.8.1 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.8.8.1}" ] || { echo "encoded cyrillic name was not matched"; false; }
}

@test "check refuses when mixed proxy is disabled" {
	dir=$(fixture)
	setting "$dir" podkop.main.mixed_proxy_enabled 0
	echo 000 >"$dir/probe"
	run tool "$dir" check
	[ "$status" -ne 0 ] || { echo "check ran without mixed proxy"; false; }
}

@test "dont restart podkop when only order differs" {
	dir=$(fixture)
	{ link o1.example "USA"; link o2.example "USA"; } >"$dir/pair"
	subscription "$dir" a <"$dir/pair"
	server "$dir" o1.example 10.8.9.1 US Texas Dallas
	server "$dir" o2.example 10.8.9.2 US Texas Dallas
	sort -r "$dir/pair" | sed -e 's/@o1.example:/@10.8.9.1:/' -e 's/@o2.example:/@10.8.9.2:/' -e 's/^/podkop.main.urltest_proxy_links=/' >>"$dir/uci"
	tool "$dir" update
	[ ! -f "$dir/restarts" ] || { echo "podkop was restarted for reordered links"; false; }
}

@test "falls back to yandex dns without bootstrap setting" {
	dir=$(fixture)
	host="v$RANDOM.example"
	server "$dir" "$host" 10.9.0.1 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(sort -u "$dir/resolvers")" = 77.88.8.8 ] || { echo "default resolver was not used"; false; }
}

@test "probes default port without port setting" {
	dir=$(fixture)
	tool "$dir" check
	[ "$(sort -u "$dir/proxies")" = socks5h://127.0.0.1:2080 ] || { echo "default mixed proxy port was not probed"; false; }
}

@test "decompresses gzip subscription without od" {
	dir=$(fixture)
	printf '#!/bin/sh\nexit 127\n' >"$dir/bin/od"
	chmod +x "$dir/bin/od"
	host="z$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.3.4.5 US Texas Dallas
	echo "$dallas" | gzip | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.3.4.5}" ] || { echo "gzip subscription was not decompressed without od"; false; }
}

@test "locates server by its exit through sing-box" {
	dir=$(fixture)
	host="e$RANDOM.example"
	server "$dir" "$host" 10.9.1.1 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(grep -c '^socks5h://127.0.0.1:' "$dir/geoproxies")" = 1 ] || { echo "geolocation did not go through the trial proxy"; false; }
}

@test "stops sing-box after trial" {
	dir=$(fixture)
	host="s$RANDOM.example"
	server "$dir" "$host" 10.9.1.2 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	! kill -0 "$(cat "$dir/trials")" 2>/dev/null || { echo "sing-box was left running after trial"; false; }
}

@test "passes reality key to sing-box" {
	dir=$(fixture)
	key="k$RANDOM$RANDOM"
	host="r$RANDOM.example"
	server "$dir" "$host" 10.9.1.3 US Texas Dallas
	echo "vless://$(uuidgen)@$host:8443?type=tcp&security=reality&pbk=$key&sid=ab&sni=www.$RANDOM.test&fp=chrome#USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(jq -r '.outbounds[0].tls.reality.public_key' "$dir/configs")" = "$key" ] || { echo "reality key did not reach sing-box"; false; }
}

@test "passes decoded websocket path to sing-box" {
	dir=$(fixture)
	segment="p$RANDOM"
	host="w$RANDOM.example"
	server "$dir" "$host" 10.9.1.4 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=ws&security=tls&path=%2F$segment%3Fed%3D2048&host=$host#USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(jq -r '.outbounds[0].transport.path' "$dir/configs")" = "/$segment?ed=2048" ] || { echo "websocket path was not decoded for sing-box"; false; }
}

@test "connects sing-box to resolved address" {
	dir=$(fixture)
	host="a$RANDOM.example"
	server "$dir" "$host" 10.9.1.5 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(jq -r '.outbounds[0].server' "$dir/configs")" = 10.9.1.5 ] || { echo "sing-box did not get resolved address"; false; }
}

@test "skips link with unsupported transport" {
	dir=$(fixture)
	host="x$RANDOM.example"
	server "$dir" "$host" 10.9.1.6 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=kcp&security=none#USA" | subscription "$dir" a
	tool "$dir" update || true
	[ ! -f "$dir/trials" ] || { echo "sing-box was started for unsupported transport"; false; }
}

@test "skips link with excluded parameter" {
	dir=$(fixture)
	value="white$RANDOM"
	setting "$dir" podkop_geo.location.exclude "x-block=$value"
	host="b$RANDOM.example"
	server "$dir" "$host" 10.9.2.1 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=tcp&x-block=$value&security=none#USA" | subscription "$dir" a
	tool "$dir" update || true
	[ -z "$(links "$dir")" ] || { echo "link with excluded parameter was written to podkop"; false; }
}

@test "keeps link whose parameter only resembles exclusion" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.exclude "x-block=white"
	host="c$RANDOM.example"
	dallas="vless://$(uuidgen)@$host:443?type=tcp&x-block=whitelist$RANDOM&security=none#USA"
	server "$dir" "$host" 10.9.2.2 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "${dallas/@$host/@10.9.2.2}" ] || { echo "link was excluded by partial match"; false; }
}

@test "writes link without spaces" {
	dir=$(fixture)
	host="g$RANDOM.example"
	server "$dir" "$host" 10.9.3.1 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=tcp&security=none#USA $RANDOM → [x y]" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir" | grep -c ' ')" = 0 ] || { echo "link with spaces was written to podkop"; false; }
}

@test "matches name split by encoded space" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.name "usa [0-9]+"
	host="h$RANDOM.example"
	server "$dir" "$host" 10.9.3.2 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=tcp&security=none#USA $RANDOM" | subscription "$dir" a
	tool "$dir" update
	[ -n "$(links "$dir")" ] || { echo "name with space was not matched after encoding"; false; }
}

@test "pins tested address into podkop link" {
	dir=$(fixture)
	host="pin$RANDOM.example"
	server "$dir" "$host" 10.9.4.1 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir" | grep -c '@10.9.4.1:443?')" = 1 ] || { echo "tested address was not pinned into the link"; false; }
}

@test "keeps original host as sni when pinning" {
	dir=$(fixture)
	host="sni$RANDOM.example"
	server "$dir" "$host" 10.9.4.2 US Texas Dallas
	echo "vless://$(uuidgen)@$host:443?type=tcp&security=tls#USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir" | grep -c "&sni=$host#")" = 1 ] || { echo "original host was lost as sni after pinning"; false; }
}

@test "keeps original host as websocket host when pinning" {
	dir=$(fixture)
	host="ws$RANDOM.example"
	server "$dir" "$host" 10.9.4.3 US Texas Dallas
	echo "vless://$(uuidgen)@$host?type=ws&path=%2F&security=none#USA" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir" | grep -c "@10.9.4.3?type=ws&path=%2F&security=none&host=$host#")" = 1 ] || { echo "original host was lost as websocket host after pinning"; false; }
}

@test "locates again when host moves to another address" {
	dir=$(fixture)
	host="mv$RANDOM.example"
	server "$dir" "$host" 10.9.4.4 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	server "$dir" "$host" 10.9.4.5 US Texas Dallas
	tool "$dir" update
	[ "$(wc -l <"$dir/geocalls" | tr -d ' ')" = 2 ] || { echo "moved host reused geolocation of old address"; false; }
}

@test "check updates when exit leaves configured city" {
	dir=$(fixture)
	printf 'success\nUS\nTexas\nIrving\n' >"$dir/exit"
	host="lv$RANDOM.example"
	server "$dir" "$host" 10.9.4.6 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" check
	[ "$(links "$dir" | grep -c '@10.9.4.6:')" = 1 ] || { echo "exit outside configured city did not trigger an update"; false; }
}

@test "check relocates cached servers when exit leaves configured city" {
	dir=$(fixture)
	host="rc$RANDOM.example"
	server "$dir" "$host" 10.9.4.7 US Texas Dallas
	link "$host" "USA" | subscription "$dir" a
	tool "$dir" update
	printf 'success\nUS\nTexas\nIrving\n' >"$dir/exit"
	rm -f "$dir/state/updated"
	tool "$dir" check || true
	[ "$(wc -l <"$dir/geocalls" | tr -d ' ')" = 2 ] || { echo "stale geolocation cache survived wrong exit"; false; }
}
