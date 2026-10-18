#!/bin/sh
set -e
[ -n "$1" ] || { echo "Usage: ./deploy.sh root@<router_ip>" >&2; exit 2; }
cd "$(dirname "$0")"
[ -f secrets ] || { echo "File secrets is missing, copy secrets.example to secrets and put your subscription URLs there" >&2; exit 1; }
scp -O podkop-geo install.sh podkop_geo.conf secrets secrets.example "$1":/tmp/
ssh "$1" 'sh /tmp/install.sh; status=$?; rm -f /tmp/secrets; [ $status -eq 0 ] && podkop-geo update'
