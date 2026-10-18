fixture() {
	dir=$(mktemp -d "$BATS_TEST_TMPDIR/router.XXXXXX")
	mkdir -p "$dir/bin" "$dir/sub" "$dir/geo" "$dir/dns"
	: >"$dir/secrets"
	: >"$dir/uci"
	echo 204 >"$dir/probe"
	cat >"$dir/bin/curl" <<STUB
#!/bin/sh
for arg; do url=\$arg; done
case "\$url" in
	https://sub.test/*) [ -f "$dir/sub/\${url##*/}" ] || exit 22; out=; prev=; for arg; do [ "\$prev" = -o ] && out=\$arg; prev=\$arg; done; cat "$dir/sub/\${url##*/}" >"\$out" ;;
	http://ip-api.com/line/*) ip=\${url#http://ip-api.com/line/}; cat "$dir/geo/\${ip%%\?*}" 2>/dev/null || printf 'fail\n' ;;
	*) cat "$dir/probe" ;;
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
	get) grep "^\$2=" "$dir/uci" | cut -d= -f2- | tr '\n' ' ' | sed 's/ \$//'; echo ;;
	delete) grep -v "^\$2=" "$dir/uci" >"$dir/uci.new"; mv "$dir/uci.new" "$dir/uci" ;;
	add_list) echo "\$2" >>"$dir/uci" ;;
	set) grep -v "^\${2%%=*}=" "$dir/uci" >"$dir/uci.new"; echo "\$2" >>"$dir/uci.new"; mv "$dir/uci.new" "$dir/uci" ;;
esac
STUB
	printf '#!/bin/sh\necho restart >>"%s/restarts"\n' "$dir" >"$dir/bin/service"
	printf '#!/bin/sh\n' >"$dir/bin/logger"
	printf '#!/bin/sh\n' >"$dir/bin/lock"
	chmod +x "$dir"/bin/*
	echo "$dir"
}

subscription() {
	echo "https://sub.test/$2" >>"$1/secrets"
	cat >"$1/sub/$2"
}

server() {
	echo "Address: $3" >"$1/dns/$2"
	printf 'success\n%s\n%s\n' "$4" "$5" >"$1/geo/$3"
}

link() {
	echo "vless://$(uuidgen)@$1:443?type=xhttp&security=reality#$2"
}

tool() {
	dir=$1
	shift
	PATH="$dir/bin:$PATH" PODKOP_DALLAS_SECRETS="$dir/secrets" PODKOP_DALLAS_SERVICE="$dir/bin/service" "$BATS_TEST_DIRNAME/../podkop-dallas" "$@" 2>/dev/null
}

links() {
	grep '^podkop.main.urltest_proxy_links=' "$1/uci" | cut -d= -f2-
}
