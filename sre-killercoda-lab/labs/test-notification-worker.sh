#!/usr/bin/env bash
# E2E Kafka -> bridge -> RabbitMQ -> worker com ACK logado.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=60s
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=60s
ID="PAG-WORKER-$(date -u +%Y%m%dT%H%M%S)-$RANDOM"
PAYLOAD=$(printf '{"pagamento_id":"%s","valor_centavos":2525,"status":"APROVADO_SIMULADO"}' "$ID")
printf '%s\n' "$PAYLOAD" |
  kubectl -n "$NS" exec -i deployment/kafka -- \
    /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic pagamentos-simulados
echo "Evento Kafka enviado: $ID"
forwarded=0
acked=0
for _i in $(seq 1 40); do
  BRIDGE_LOG=$(kubectl -n "$NS" logs deployment/payment-bridge --since=3m --tail=200 2>/dev/null || true)
  WORKER_LOG=$(kubectl -n "$NS" logs deployment/notification-worker --since=3m --tail=200 2>/dev/null || true)
  if printf '%s\n' "$BRIDGE_LOG" | grep -F '"event": "FORWARDED"' | grep -Fq "$ID"; then
    forwarded=1
  fi
  if printf '%s\n' "$WORKER_LOG" | grep -F '"event": "ACK"' | grep -Fq "$ID"; then
    acked=1
  fi
  if [[ "$forwarded" -eq 1 && "$acked" -eq 1 ]]; then
    echo "=== KAFKA -> RABBITMQ ==="
    printf '%s\n' "$BRIDGE_LOG" | grep -F '"event": "FORWARDED"' | grep -F "$ID" | tail -1
    echo "=== RABBITMQ -> WORKER ACK ==="
    printf '%s\n' "$WORKER_LOG" | grep -F '"event": "ACK"' | grep -F "$ID" | tail -1
    echo "SUCESSO: Kafka -> bridge -> RabbitMQ -> worker confirmado por logs."
    exit 0
  fi
  sleep 2
done
echo "FALHA: fluxo não completou em até 80 segundos (FORWARDED=$forwarded, ACK=$acked)." >&2
kubectl -n "$NS" logs deployment/payment-bridge --tail=35 || true
kubectl -n "$NS" logs deployment/notification-worker --tail=35 || true
exit 1
