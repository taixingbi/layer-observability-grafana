#!/bin/sh
set -e
BASE=/etc/prometheus/prometheus.yml
FLAGS="--storage.tsdb.path=/prometheus --web.enable-lifecycle"
OUT=/tmp/prometheus.yml

rw_url_len=${#GRAFANA_CLOUD_PROMETHEUS_URL}
rw_user_len=${#GRAFANA_CLOUD_PROMETHEUS_USER}

if [ "$rw_url_len" -gt 0 ] && [ "$rw_user_len" -gt 0 ]; then
  if [ ! -f /run/prometheus-secrets/grafana_cloud_rw ]; then
    echo "prometheus: Grafana Cloud remote_write needs secrets/grafana_cloud_rw" >&2
    exit 1
  fi
  export GRAFANA_CLOUD_PROMETHEUS_URL GRAFANA_CLOUD_PROMETHEUS_USER
  awk '
    BEGIN { rw_done = 0 }
    /^scrape_configs:/ && !rw_done {
      print "remote_write:"
      print "  - url: \"" ENVIRON["GRAFANA_CLOUD_PROMETHEUS_URL"] "\""
      print "    basic_auth:"
      print "      username: \"" ENVIRON["GRAFANA_CLOUD_PROMETHEUS_USER"] "\""
      print "      password_file: /run/prometheus-secrets/grafana_cloud_rw"
      print ""
      rw_done = 1
    }
    { print }
  ' "$BASE" >"$OUT"
  exec /bin/prometheus --config.file="$OUT" $FLAGS
fi

if [ "$rw_url_len" -gt 0 ] || [ "$rw_user_len" -gt 0 ]; then
  echo "prometheus: set both GRAFANA_CLOUD_PROMETHEUS_URL and GRAFANA_CLOUD_PROMETHEUS_USER, or neither" >&2
  exit 1
fi

exec /bin/prometheus --config.file="$BASE" $FLAGS
