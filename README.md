# Layer observability (Prometheus + Grafana Cloud)

Prometheus runs on this host and scrapes GPU/vLLM targets defined in `prometheus/prometheus.yml`.  
Grafana Cloud remote write is optional and configured from `.env`.

## Prerequisites

- Docker Engine with Compose v2
- Network access from this host to all scrape targets in `prometheus/prometheus.yml`
- Port `9090` available on this host

## Configuration

Create `.env` from `.env.example`:

```bash
cp .env.example .env
```

`.env` supports two modes:

- Local-only mode: leave all Grafana Cloud variables empty
- Remote-write mode: set all three values
  - `GRAFANA_CLOUD_PROMETHEUS_URL`
  - `GRAFANA_CLOUD_PROMETHEUS_USER`
  - `GRAFANA_CLOUD_API_KEY`

If only some variables are set, remote write is disabled and Prometheus still starts in local-only mode.

## Start / restart

```bash
sudo docker compose down
sudo docker compose up -d
```

Access Prometheus:

- `http://localhost:9090`

## Enable Grafana Cloud remote write

1. In Grafana Cloud hosted Prometheus, copy:
   - remote write URL
   - instance ID (user)
2. Create an access policy token with `metrics:write`
3. Put values in `.env`:

```bash
GRAFANA_CLOUD_PROMETHEUS_URL=https://prometheus-prod-....grafana.net/api/prom/push
GRAFANA_CLOUD_PROMETHEUS_USER=123456
GRAFANA_CLOUD_API_KEY=glc_xxx
```

4. Restart:

```bash
sudo docker compose up -d
```

## Apply config changes

- Changed `prometheus/prometheus.yml` only:

```bash
curl -X POST http://localhost:9090/-/reload
```

- Changed `.env` (remote write settings): restart container with `docker compose up -d`

## Troubleshooting

Useful checks:

```bash
sudo docker compose ps
sudo docker compose logs --tail=100 prometheus
curl -sf http://localhost:9090/-/healthy
```

Common issues:

- Container is not running due to startup/config errors
- Remote write vars are incomplete (`URL`, `USER`, `API_KEY` must all be set)
- Port `9090` is already in use by another process
