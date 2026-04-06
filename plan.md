# Monitoring plan

## Targets

### gpu-node-1
- GPU: `http://192.168.86.173:9400/metrics`
- vLLM inference: `http://192.168.86.173:30080/metrics`
- vLLM embed: `http://192.168.86.173:8001/metrics`

### gpu-node-2
- GPU: `http://192.168.86.176:9400/metrics`
- vLLM inference: `http://192.168.86.176:30080/metrics`
- vLLM embed: `http://192.168.86.176:8001/metrics`

## Recommended architecture

- `gpu-node-1`: `dcgm-exporter` on `:9400`, vLLM inference on `:30080`, vLLM embed on `:8001`
- `gpu-node-2`: `dcgm-exporter` on `:9400`, vLLM inference on `:30080`, vLLM embed on `:8001`
- `server-node`: Prometheus + Grafana

Design:

```text
server-node
├── Prometheus
└── Grafana
```

Prometheus scrapes:

```text
gpu-node-1:9400
gpu-node-1:30080
gpu-node-1:8001
gpu-node-2:9400
gpu-node-2:30080
gpu-node-2:8001
```

## Recommended Prometheus job split

Use separate jobs (do not combine all endpoints into one job):

```yaml
scrape_configs:
  - job_name: dcgm-gpu-node-1
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.173:9400']
        labels:
          node: gpu-node-1
          service: gpu

  - job_name: dcgm-gpu-node-2
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.176:9400']
        labels:
          node: gpu-node-2
          service: gpu

  - job_name: vllm-inference-gpu-node-1
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.173:30080']
        labels:
          node: gpu-node-1
          service: inference
          model: Qwen/Qwen2.5-7B-Instruct

  - job_name: vllm-inference-gpu-node-2
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.176:30080']
        labels:
          node: gpu-node-2
          service: inference
          model: Qwen/Qwen2.5-7B-Instruct

  - job_name: vllm-embed-gpu-node-1
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.173:8001']
        labels:
          node: gpu-node-1
          service: embedding
          model: BAAI/bge-m3

  - job_name: vllm-embed-gpu-node-2
    metrics_path: /metrics
    static_configs:
      - targets: ['192.168.86.176:8001']
        labels:
          node: gpu-node-2
          service: embedding
          model: BAAI/bge-m3
```

## Best dashboard layout

Build 3 dashboards.

### 1) GPU dashboard (both nodes)

Track:
- GPU utilization
- GPU memory used
- GPU temperature
- GPU power
- SM clock
- XID errors

Use `node` label (`gpu-node-1`, `gpu-node-2`) for side-by-side comparison.

### 2) Inference dashboard (`:30080` on both nodes)

Track:
- running requests
- waiting requests
- prompt tokens/sec
- generation tokens/sec
- TTFT
- e2e latency
- queue time
- KV cache usage

### 3) Embedding dashboard (`:8001` on both nodes)

Track:
- request rate
- input token throughput
- request latency
- running requests
- waiting requests

## Best first panels (match GPU set above)

Start with these 12:

### GPU
- **GPU Utilization (%)**: `DCGM_FI_DEV_GPU_UTIL`
- **GPU Memory Used (MiB)**: `DCGM_FI_DEV_FB_USED`
- **GPU Temperature (C)**: `DCGM_FI_DEV_GPU_TEMP`
- **GPU Power Usage (W)**: `DCGM_FI_DEV_POWER_USAGE`
- **SM Clock (MHz)**: `DCGM_FI_DEV_SM_CLOCK`
- **XID Errors (count)**: `DCGM_FI_DEV_XID_ERRORS`

### Inference
- **Inference Running Requests**: `vllm:num_requests_running{service="inference"}`
- **Inference Waiting Requests**: `vllm:num_requests_waiting{service="inference"}`
- **Prompt Tokens/sec**: `rate(vllm:prompt_tokens_total{service="inference"}[1m])`
- **Generation Tokens/sec**: `rate(vllm:generation_tokens_total{service="inference"}[1m])`

### Embedding
- **Embedding Running Requests**: `vllm:num_requests_running{service="embedding"}`
- **Embedding Request Success/sec**: `rate(vllm:request_success_total{service="embedding"}[1m])`