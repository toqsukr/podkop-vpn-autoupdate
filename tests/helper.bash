fixture() {
	dir=$(mktemp -d "$BATS_TEST_TMPDIR/router.XXXXXX")
	mkdir -p "$dir/bin" "$dir/sub" "$dir/geo" "$dir/dns"
	: >"$dir/secrets"
	printf "podkop_geo.location.name=usa\npodkop_geo.location.country=US\npodkop_geo.location.region=Texas\npodkop_geo.location.city=Dallas\npodkop.main.mixed_proxy_enabled=1\n" >"$dir/uci"
	echo 204 >"$dir/probe"
	printf 'success\nUS\nTexas\nDallas\n' >"$dir/exit"
	cat >"$dir/bin/curl" <<STUB
#!/bin/sh
for arg; do url=\$arg; done
case "\$url" in
	https://sub.test/*) [ -f "$dir/sub/\${url##*/}" ] || exit 22; out=; prev=; for arg; do [ "\$prev" = -o ] && out=\$arg; prev=\$arg; done; cat "$dir/sub/\${url##*/}" >"\$out" ;;
	http://ip-api.com/line*) case " \$* " in *" socks5h://127.0.0.1:2080 "*) cat "$dir/exit"; exit ;; esac; [ -f "$dir/running" ] || exit 7; echo "\$url" >>"$dir/geocalls"; prev=; for arg; do [ "\$prev" = -x ] && echo "\$arg" >>"$dir/geoproxies"; prev=\$arg; done; ip=\$(grep -o '"server":"[^"]*"' "$dir/running" | cut -d'"' -f4); cat "$dir/geo/\$ip" 2>/dev/null || printf 'fail\n' ;;
	*) prev=; for arg; do [ "\$prev" = -x ] && echo "\$arg" >>"$dir/proxies"; prev=\$arg; done; cat "$dir/probe" ;;
esac
STUB
	cat >"$dir/bin/nslookup" <<STUB
#!/bin/sh
echo "\$2" >>"$dir/resolvers"
printf 'Server:\t\t%s\nAddress:\t%s:53\n\nName:\t%s\n' "\$2" "\$2" "\$1"
cat "$dir/dns/\$1" 2>/dev/null
STUB
	cat >"$dir/bin/uci" <<STUB
#!/bin/sh
[ "\$1" = -q ] && shift
case "\$1" in
	get) grep -q "^\$2=" "$dir/uci" || exit 1; grep "^\$2=" "$dir/uci" | cut -d= -f2- | tr '\n' ' ' | sed 's/ \$//'; echo ;;
	delete) grep -v "^\$2=" "$dir/uci" >"$dir/uci.new"; mv "$dir/uci.new" "$dir/uci" ;;
	add_list) echo "\$2" >>"$dir/uci" ;;
	set) grep -v "^\${2%%=*}=" "$dir/uci" >"$dir/uci.new"; echo "\$2" >>"$dir/uci.new"; mv "$dir/uci.new" "$dir/uci" ;;
esac
STUB
	printf '#!/bin/sh\ntrap "rm -f %s/running; exit" TERM\ncp "$3" "%s/running"\ncat "$3" >>"%s/configs"\necho $$ >>"%s/trials"\nsleep 30 &\nwait\n' "$dir" "$dir" "$dir" "$dir" >"$dir/bin/sing-box"
	printf '#!/bin/sh\necho restart >>"%s/restarts"\n' "$dir" >"$dir/bin/service"
	printf '#!/bin/sh\necho "$*" >>"%s/log"\n' "$dir" >"$dir/bin/logger"
	chmod +x "$dir"/bin/*
	echo "$dir"
}

subscription() {
	echo "https://sub.test/$2" >>"$1/secrets"
	cat >"$1/sub/$2"
}

server() {
	echo "Address: $3" >"$1/dns/$2"
	printf 'success\n%s\n%s\n%s\n' "$4" "$5" "$6" >"$1/geo/$3"
}

link() {
	echo "vless://$(uuidgen)@$1:443?type=tcp&security=reality&pbk=k$RANDOM&sni=s$RANDOM.test#$2"
}

tool() {
	dir=$1
	shift
	PATH="$dir/bin:$PATH" PODKOP_GEO_SECRETS="$dir/secrets" PODKOP_GEO_SERVICE="$dir/bin/service" PODKOP_GEO_LOCK="$dir/lock.pid" PODKOP_GEO_STATE="$dir/state" PODKOP_GEO_TRIAL=$((20000 + RANDOM % 10000)) "$BATS_TEST_DIRNAME/../podkop-geo" "$@" 2>/dev/null
}

links() {
	grep '^podkop.main.urltest_proxy_links=' "$1/uci" | cut -d= -f2-
}

setting() {
	grep -v "^$2=" "$1/uci" >"$1/uci.new"
	echo "$2=$3" >>"$1/uci.new"
	mv "$1/uci.new" "$1/uci"
}
