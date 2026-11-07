#!/usr/bin/env bash
# Demonstra métricas Prometheus do Worker sem instalar Prometheus em cluster pequeno.
set -euo pipefail
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=120s
echo "=== SCRAPE /metrics PELO POD ==="
kubectl -n "$NS" exec deployment/notification-worker -- \
  python -c 'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:9100/metrics", timeout=5).read().decode())'
echo "=== SERVICE DE METRICAS ==="
kubectl -n "$NS" get service notification-worker-metrics
echo "SUGESTAO: produza mensagens com test-idempotencia.sh e execute novamente para ver os contadores."
echo "AVISO: os contadores reiniciam a cada restart do Pod."
