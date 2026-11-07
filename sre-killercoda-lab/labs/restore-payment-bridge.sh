#!/usr/bin/env bash
# Implanta a bridge que consome eventos FICTICIOS do Kafka e publica no RabbitMQ.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/kafka --timeout=90s
kubectl -n "$NS" rollout status deployment/rabbitmq --timeout=90s
kubectl -n "$NS" exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 --create --if-not-exists \
  --topic pagamentos-simulados --partitions 1 --replication-factor 1
kubectl -n "$NS" create configmap payment-bridge-code \
  --from-file=bridge.py=apps/payment-bridge/bridge.py \
  --from-file=requirements.txt=apps/payment-bridge/requirements.txt \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f labs/payment-bridge.yaml
echo "A bridge instala bibliotecas na inicialização; aguarde os logs BRIDGE_START."
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=180s || {
  echo "A bridge pode estar instalando pacotes ou reiniciando; veja os logs e os eventos."
  kubectl -n "$NS" get pods -l app=payment-bridge -o wide
  exit 1
}
kubectl -n "$NS" logs deploy/payment-bridge --tail=30
