#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/apache --timeout=90s
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=90s
kubectl -n "$NS" create configmap sre-observer-code \
  --from-file=collector.py=apps/observability/collector.py \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f labs/sre-observer.yaml
kubectl -n "$NS" rollout restart deployment/sre-observer
kubectl -n "$NS" rollout status deployment/sre-observer --timeout=120s
kubectl -n "$NS" get pvc sre-observer-data
kubectl -n "$NS" logs deployment/sre-observer --tail=12
