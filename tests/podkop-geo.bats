load helper

@test "picks dallas server from plain subscription" {
	dir=$(fixture)
	host="d$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.1.2.3 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "dallas link was not written to podkop"; false; }
}

@test "decodes base64 subscription" {
	dir=$(fixture)
	host="b$RANDOM.example"
	dallas=$(link "$host" "%F0%9F%87%BA%F0%9F%87%B8%20USA")
	server "$dir" "$host" 10.4.5.6 US Texas Dallas
	echo "$dallas" | base64 | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "base64 subscription was not decoded"; false; }
}

@test "decodes urlsafe base64 without padding" {
	dir=$(fixture)
	host="u$RANDOM.example"
	dallas="$(link "$host" "USA")&x=??>>"
	server "$dir" "$host" 10.7.8.9 US Texas Dallas
	printf '%s\n' "$dallas" | base64 | tr '/+' '_-' | tr -d '=' | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "urlsafe base64 was not decoded"; false; }
}

@test "decompresses gzip subscription" {
	dir=$(fixture)
	host="g$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.3.3.3 US Texas Dallas
	echo "$dallas" | gzip | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "gzip subscription was not decompressed"; false; }
}

@test "finds dallas in second subscription" {
	dir=$(fixture)
	link "nl$RANDOM.example" "Netherlands" | subscription "$dir" a
	host="s$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.2.2.2 US Texas Dallas
	echo "$dallas" | subscription "$dir" b
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "dallas from second subscription was not found"; false; }
}

@test "skips usa server outside dallas" {
	dir=$(fixture)
	{ link ny.example "USA"; link dl.example "USA"; } | subscription "$dir" a
	server "$dir" ny.example 10.9.9.1 US "New York" "New York"
	server "$dir" dl.example 10.9.9.2 US Texas Dallas
	tool "$dir" update
	[ "$(links "$dir" | grep -c ny.example)" = 0 ] || { echo "new york server was not skipped"; false; }
}

@test "falls back to texas region" {
	dir=$(fixture)
	host="t$RANDOM.example"
	texas=$(link "$host" "USA")
	server "$dir" "$host" 10.6.6.6 US Texas Irving
	echo "$texas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$texas" ] || { echo "texas server was not used as fallback"; false; }
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
	[ "$(links "$dir")" = "$dallas" ] || { echo "broken subscription stopped the update"; false; }
}

@test "dont restart podkop when servers are unchanged" {
	dir=$(fixture)
	host="c$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.8.8.8 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	echo "podkop.main.urltest_proxy_links=$dallas" >>"$dir/uci"
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
	[ "$(links "$dir")" = "$dallas" ] || { echo "dead proxy did not trigger an update"; false; }
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
	[ "$(links "$dir" | grep -c mi.example)" = 1 ] || { echo "configured city was not picked"; false; }
}

@test "matches city ignoring case" {
	dir=$(fixture)
	setting "$dir" podkop_geo.location.city dALLas
	host="i$RANDOM.example"
	dallas=$(link "$host" "USA")
	server "$dir" "$host" 10.7.1.1 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "city case was not ignored"; false; }
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
	[ "$(links "$dir")" = "$amsterdam" ] || { echo "country alone did not select a server"; false; }
}

@test "checks every link when name filter is empty" {
	dir=$(fixture)
	printf 'podkop_geo.location.city=Dallas\n' >"$dir/uci"
	host="q$RANDOM.example"
	dallas=$(link "$host" "Premium-$RANDOM")
	server "$dir" "$host" 10.7.4.4 US Texas Dallas
	echo "$dallas" | subscription "$dir" a
	tool "$dir" update
	[ "$(links "$dir")" = "$dallas" ] || { echo "unnamed link was not checked"; false; }
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
