# Layer observability (Prometheus + Grafana Cloud)

Prometheus on **server-node-1** (Docker) scrapes DCGM and vLLM on two GPU nodes. Optional **remote_write** sends metrics to [Grafana Cloud](https://grafana.com/docs/grafana-cloud/send-data/metrics/); dashboards are **imported** from [dashboards/](dashboards/). Targets match [plan.md](plan.md).

## Requirements
- Docker Engine + Compose v2 ([Ubuntu install](https://docs.docker.com/engine/install/ubuntu/))
- From server-node-1: reach scrape targets in [prometheus/prometheus.yml](prometheus/prometheus.yml)
- For Grafana Cloud: outbound HTTPS to your `remote_write` host

## .env 
https://grafana.com/orgs/taixingbi/hosted-metrics/3067716
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-56-prod-us-east-2.grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=3067716

## Quick start

```bash
mkdir -p secrets
sudo docker compose down
docker compose up -d
```

- Prometheus: `http://<server>:9090` (on host: `http://localhost:9090`).
- **Grafana Cloud:** in `.env`, set `GRAFANA_CLOUD_PROMETHEUS_URL` and `GRAFANA_CLOUD_PROMETHEUS_USER`, add token file [secrets/README](secrets/README), then `docker compose up -d` (see below).

## Grafana Cloud remote_write

1. Stack → **Send metrics** / hosted Prometheus: copy **remote write URL** and numeric **user** (instance ID).
2. Create a token with **metrics:write** ([access policies](https://grafana.com/docs/grafana-cloud/account-management/authentication-and-permissions/access-policies/)).
3. `printf '%s' 'YOUR_GRAFANA_CLOUD_TOKEN' > secrets/grafana_cloud_rw && chmod 600 secrets/grafana_cloud_rw`
4. `.env`:

   ```bash
   GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-....grafana.net/api/prom/push
   GRAFANA_CLOUD_PROMETHEUS_USER=123456
   ```

5. `docker compose up -d`. Remote config is generated at container start; after changing `.env` or the token, run `docker compose up -d` again.

## Config reload

Edits to [prometheus/prometheus.yml](prometheus/prometheus.yml) (scrapes only):

```bash
curl -X POST http://localhost:9090/-/reload
```

If remote_write env or token changed, **restart** the container instead of reload.
