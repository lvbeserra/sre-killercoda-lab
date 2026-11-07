#!/usr/bin/env bash
# Recupera Worker com deduplicação SQLite/PVC e DLQ RabbitMQ.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/rabbitmq --timeout=90s
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=90s

echo "=== CONFIGURANDO DLQ PARA REJEIÇÕES ==="
# O worker declara a DLQ durável ao iniciar, antes de consumir mensagens.
# O RabbitMQ roteará mensagens rejeitadas para a fila com o nome abaixo.
kubectl -n "$NS" exec deployment/rabbitmq -- \
  rabbitmqctl set_policy -p / --apply-to queues \
  sre-notificacoes-dlq '^notificacoes-pagamentos$' \
  '{"dead-letter-exchange":"","dead-letter-routing-key":"notificacoes-pagamentos-dlq"}'

echo "=== APLICANDO CÓDIGO E VOLUME PERSISTENTE ==="
kubectl -n "$NS" create configmap notification-worker-code \
  --from-file=worker.py=apps/notification-worker/worker.py \
  --from-file=requirements.txt=apps/notification-worker/requirements.txt \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f labs/notification-worker.yaml
# Recomeça para garantir Python atualizado mesmo se só ConfigMap mudou.
kubectl -n "$NS" rollout restart deployment/notification-worker
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=180s
kubectl -n "$NS" get pvc notification-worker-data
kubectl -n "$NS" logs deployment/notification-worker --tail=20
