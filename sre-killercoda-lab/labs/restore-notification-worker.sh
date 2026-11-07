#!/usr/bin/env bash
# Recupera consumidor RabbitMQ do lab; mensagens apenas fictícias.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/rabbitmq --timeout=90s
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=90s
kubectl -n "$NS" create configmap notification-worker-code \
  --from-file=worker.py=apps/notification-worker/worker.py \
  --from-file=requirements.txt=apps/notification-worker/requirements.txt \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f labs/notification-worker.yaml
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=180s
kubectl -n "$NS" logs deployment/notification-worker --tail=15
