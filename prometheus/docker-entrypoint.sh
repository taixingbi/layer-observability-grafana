#!/bin/sh
set -e
BASE=/etc/prometheus/prometheus.yml
FLAGS="--storage.tsdb.path=/prometheus --web.enable-lifecycle"
OUT=/tmp/prometheus.yml

rw_url_len=${#GRAFANA_CLOUD_PROMETHEUS_URL}
rw_user_len=${#GRAFANA_CLOUD_PROMETHEUS_USER}
rw_key_len=${#GRAFANA_CLOUD_API_KEY}

start_prometheus() {
  exec /bin/prometheus --config.file="$1" $FLAGS
}

if [ "$rw_url_len" -gt 0 ] && [ "$rw_user_len" -gt 0 ] && [ "$rw_key_len" -gt 0 ]; then
  export GRAFANA_CLOUD_PROMETHEUS_URL GRAFANA_CLOUD_PROMETHEUS_USER GRAFANA_CLOUD_API_KEY
  awk '
    BEGIN { rw_done = 0 }
    /^scrape_configs:/ && !rw_done {
      print "remote_write:"
      print "  - url: \"" ENVIRON["GRAFANA_CLOUD_PROMETHEUS_URL"] "\""
      print "    basic_auth:"
      print "      username: \"" ENVIRON["GRAFANA_CLOUD_PROMETHEUS_USER"] "\""
      print "      password: \"" ENVIRON["GRAFANA_CLOUD_API_KEY"] "\""
      print ""
      rw_done = 1
    }
    { print }
  ' "$BASE" >"$OUT"
  start_prometheus "$OUT"
fi

if [ "$rw_url_len" -gt 0 ] || [ "$rw_user_len" -gt 0 ] || [ "$rw_key_len" -gt 0 ]; then
  echo "prometheus: incomplete Grafana Cloud env vars (need URL, USER, API_KEY); remote_write disabled and starting local Prometheus only" >&2
  start_prometheus "$BASE"
fi

start_prometheus "$BASE"
