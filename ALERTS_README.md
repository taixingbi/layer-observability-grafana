# Grafana Alert Plan

Alerts for three dashboards: **GPU (DCGM)**, **vLLM inference (Qwen)**, and **vLLM embedding (bge-m3)**.  
All expressions target Grafana Alerting / Prometheus ruler. Adjust `for:` durations to match your scrape interval (default assumes 15–30 s).

---

## Severity legend

| Symbol | Level | Action |
|--------|-------|--------|
| 🔴 | Critical | Page on-call immediately |
| 🟡 | Warning | Ticket / Slack notification |
| 🔵 | Info | Log only / dead-node awareness |

---

## 1. GPU (DCGM)

> Dashboard UID: `layer-gpu-dcgm` · label filter: `service="gpu"`

### GPU utilization

```yaml
- alert: GpuUtilizationCritical
  expr: DCGM_FI_DEV_GPU_UTIL{service="gpu"} > 95
  for: 5m
  severity: critical
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} utilization > 95% for 5 min"

- alert: GpuUtilizationWarning
  expr: DCGM_FI_DEV_GPU_UTIL{service="gpu"} > 85
  for: 10m
  severity: warning
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} utilization > 85% for 10 min"
```

### GPU memory

```yaml
- alert: GpuMemoryCritical
  expr: >
    DCGM_FI_DEV_FB_USED{service="gpu"}
    / DCGM_FI_DEV_FB_TOTAL{service="gpu"} > 0.95
  for: 2m
  severity: critical
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} memory > 95%"

- alert: GpuMemoryWarning
  expr: >
    DCGM_FI_DEV_FB_USED{service="gpu"}
    / DCGM_FI_DEV_FB_TOTAL{service="gpu"} > 0.85
  for: 5m
  severity: warning
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} memory > 85%"
```

### GPU temperature

```yaml
- alert: GpuTemperatureCritical
  expr: DCGM_FI_DEV_GPU_TEMP{service="gpu"} > 85
  for: 2m
  severity: critical
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} temperature > 85 °C"

- alert: GpuTemperatureWarning
  expr: DCGM_FI_DEV_GPU_TEMP{service="gpu"} > 75
  for: 5m
  severity: warning
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} temperature > 75 °C"
```

### GPU power

```yaml
# Set threshold to your card's TDP (e.g. 400 W for H100 SXM5)
- alert: GpuPowerSpike
  expr: DCGM_FI_DEV_POWER_USAGE{service="gpu"} > 400
  for: 5m
  severity: warning
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} power draw at or above TDP for 5 min"
```

### SM clock throttle

```yaml
- alert: GpuSmClockThrottle
  expr: >
    DCGM_FI_DEV_SM_CLOCK{service="gpu"}
    < on(node, gpu)
      (max_over_time(DCGM_FI_DEV_SM_CLOCK{service="gpu"}[1h]) * 0.80)
  for: 3m
  severity: warning
  annotations:
    summary: "GPU {{ $labels.node }} GPU {{ $labels.gpu }} SM clock dropped below 80% of 1-hour peak (thermal/power throttle)"
```

### XID errors

```yaml
# Any new XID in a 5-minute window is actionable — XIDs often signal hardware faults
- alert: GpuXidError
  expr: increase(DCGM_FI_DEV_XID_ERRORS{service="gpu"}[5m]) > 0
  for: 0m
  severity: critical
  annotations:
    summary: "XID error on {{ $labels.node }} GPU {{ $labels.gpu }} — check nvidia-smi and dmesg"
```

---

## 2. vLLM inference (Qwen)

> Dashboard UID: `layer-vllm-inference` · label filter: `service="inference"`

### Request queue

```yaml
- alert: InferenceQueueWarning
  expr: vllm:num_requests_waiting{service="inference"} > 20
  for: 2m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} inference queue > 20 requests"

- alert: InferenceQueueCritical
  expr: vllm:num_requests_waiting{service="inference"} > 50
  for: 2m
  severity: critical
  annotations:
    summary: "{{ $labels.node }} inference queue > 50 requests — likely backpressure or stalled workers"
```

### Generation throughput

```yaml
# Guard: only fires when traffic is actually present (prompt_tokens_total > 0)
- alert: InferenceGenerationThroughputLow
  expr: >
    rate(vllm:generation_tokens_total{service="inference"}[2m]) < 100
    and rate(vllm:prompt_tokens_total{service="inference"}[2m]) > 0
  for: 3m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} generation throughput < 100 tok/s despite active traffic"
```

### Time to first token (TTFT)

```yaml
- alert: InferenceTtftWarning
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:time_to_first_token_seconds_bucket{service="inference"}[5m]))
      by (le, node)
    ) > 2
  for: 5m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} p99 TTFT > 2 s"

- alert: InferenceTtftCritical
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:time_to_first_token_seconds_bucket{service="inference"}[5m]))
      by (le, node)
    ) > 5
  for: 2m
  severity: critical
  annotations:
    summary: "{{ $labels.node }} p99 TTFT > 5 s — users experiencing severe first-token delay"
```

### End-to-end latency

```yaml
- alert: InferenceE2eLatencyHigh
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:e2e_request_latency_seconds_bucket{service="inference"}[5m]))
      by (le, node)
    ) > 10
  for: 5m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} p99 end-to-end latency > 10 s"
```

### Queue time

```yaml
- alert: InferenceQueueTimeHigh
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:request_queue_time_seconds_bucket{service="inference"}[5m]))
      by (le, node)
    ) > 3
  for: 3m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} p99 queue time > 3 s — scheduler or concurrency issue"
```

### KV cache

```yaml
# KV cache exhaustion causes request rejection / stalls — most critical inference alert
- alert: InferenceKvCacheCritical
  expr: vllm:gpu_cache_usage_perc{service="inference"} > 0.90
  for: 3m
  severity: critical
  annotations:
    summary: "{{ $labels.node }} KV cache > 90% — imminent OOM / request drops"

- alert: InferenceKvCacheWarning
  expr: vllm:gpu_cache_usage_perc{service="inference"} > 0.75
  for: 5m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} KV cache > 75%"
```

### Dead node

```yaml
- alert: InferenceNodeDead
  expr: rate(vllm:prompt_tokens_total{service="inference"}[5m]) == 0
  for: 10m
  severity: info
  annotations:
    summary: "{{ $labels.node }} has received zero prompt tokens for 10 min — node may be down or unreachable"
```

---

## 3. vLLM embedding (bge-m3)

> Dashboard UID: `layer-vllm-embedding` · label filter: `service="embedding"`

### Request rate

```yaml
# Fires when near-zero successes but traffic is expected — adjust baseline to your SLA
- alert: EmbeddingRequestRateDrop
  expr: rate(vllm:request_success_total{service="embedding"}[5m]) < 0.1
  for: 5m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} embedding success rate near zero"
```

### Request queue

```yaml
- alert: EmbeddingQueueWarning
  expr: vllm:num_requests_waiting{service="embedding"} > 30
  for: 2m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} embedding queue > 30 requests"

- alert: EmbeddingQueueCritical
  expr: vllm:num_requests_waiting{service="embedding"} > 80
  for: 2m
  severity: critical
  annotations:
    summary: "{{ $labels.node }} embedding queue > 80 requests"
```

### Request latency (p99 e2e)

```yaml
- alert: EmbeddingLatencyWarning
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:e2e_request_latency_seconds_bucket{service="embedding"}[5m]))
      by (le, node)
    ) > 1
  for: 5m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} p99 embedding latency > 1 s"

- alert: EmbeddingLatencyCritical
  expr: >
    histogram_quantile(0.99,
      sum(rate(vllm:e2e_request_latency_seconds_bucket{service="embedding"}[5m]))
      by (le, node)
    ) > 3
  for: 2m
  severity: critical
  annotations:
    summary: "{{ $labels.node }} p99 embedding latency > 3 s"
```

### Input token throughput

```yaml
- alert: EmbeddingThroughputLow
  expr: >
    rate(vllm:prompt_tokens_total{service="embedding"}[2m]) < 200
    and rate(vllm:request_success_total{service="embedding"}[2m]) > 0
  for: 3m
  severity: warning
  annotations:
    summary: "{{ $labels.node }} embedding throughput < 200 tok/s despite active traffic"
```

### Dead node

```yaml
- alert: EmbeddingNodeDead
  expr: rate(vllm:request_success_total{service="embedding"}[5m]) == 0
  for: 10m
  severity: info
  annotations:
    summary: "{{ $labels.node }} has received zero successful embedding requests for 10 min"
```

---

## Tuning notes

| Item | Note |
|------|------|
| **GPU power threshold** | Replace `> 400` with your card's actual TDP (e.g. 300 W for A100 40 GB, 700 W for H100 NVL) |
| **Throughput floors** | `< 100 tok/s` (inference) and `< 200 tok/s` (embedding) are starting points — calibrate against your observed idle/loaded baseline |
| **`for:` durations** | All assume a 15–30 s Prometheus scrape interval; halve the durations if you scrape every 5 s |
| **Traffic guard** | Throughput-drop and rate-drop alerts include an `and ... > 0` guard to suppress false positives during idle periods |
| **XID `for: 0m`** | Intentionally zero — any XID should page immediately without waiting |
| **Embedding has no KV cache / TTFT** | bge-m3 is an encoder-only model; vLLM does not expose KV cache or TTFT metrics for embedding workloads |
