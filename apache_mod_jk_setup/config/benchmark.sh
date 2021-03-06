#!/usr/bin/env bash
set -eufo pipefail

function ensure_service_available() {
  local service_address="$1"
  for i in {1..120}; do 
    curl -s "${service_address}" >/dev/null && break || true
    sleep 1
  done
  curl -s "${service_address}" >/dev/null || { echo "service: ${service_address} did not respond in 2 minutes" >&2; exit 1;}
}

: ${grafan_host:="http://grafana:3000"}
: ${haproxy_host:="http://haproxy:80"}
: ${haproxy_path:="${haproxy_host}/hello/"}


/grafana_setup.sh

echo "ensure haproxy is responding"
ensure_service_available "${haproxy_host}"

epoche_start="$(date +%s)"

echo "initial wait"
sleep 10

echo "run apache benchmark"
# ab -r -s 300 -n 100000 -c 30 "${haproxy_path}"
#ab -r -s 300 -n 10000 -c 1000 "${haproxy_path}"
  # -k reuse session
#siege -d60 -t60m -c20 "${haproxy_path}"
#siege -t10s -c2 "${haproxy_path}"
siege -t15m -c500 -d60 "${haproxy_host}/hello/memory_usage?usage=5"

echo "final wait"
sleep 10

epoche_end="$(date +%s)"
second_duration="$(( $epoche_end - $epoche_start + 30 ))"

echo "render dashboard"
curl -s --user "admin:admin" \
  "${grafan_host}/render/dashboard/db/dashboard\
?orgId=1\
&from=now-${second_duration}s\
&to=now\
&kiosk\
&tz=CET\
&width=1200\
&timeout=10000\
" \
  > /grafana_render/render_$(date +%FT%H_%M_%S).png

echo "finished"

