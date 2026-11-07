#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl apply -f labs/middleware-stack.yaml
if ! kubectl -n "$NS" get secret rabbitmq-auth >/dev/null 2>&1; then
  PASS=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
  kubectl -n "$NS" create secret generic rabbitmq-auth --from-literal=password="$PASS" >/dev/null
  unset PASS
  echo "Credencial de laboratório RabbitMQ gerada (não versionada)."
fi
kubectl -n "$NS" rollout status deploy/apache --timeout=120s || true
kubectl -n "$NS" rollout status deploy/kafka --timeout=240s || true
kubectl -n "$NS" rollout status deploy/rabbitmq --timeout=240s || true
kubectl -n "$NS" get pods,svc -o wide
echo "Teste: bash labs/validate-middleware.sh"
