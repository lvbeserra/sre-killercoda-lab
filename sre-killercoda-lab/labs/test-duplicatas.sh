#!/usr/bin/env bash
# Aula SRE - testar duplicatas: Kafka -> Bridge -> RabbitMQ -> Worker.
# Publica duas mensagens com MESMO pagamento_id para demonstrar ausência
# de deduplicação no laboratório. NÃO utiliza pagamentos reais.
set -euo pipefail

NS=sre-middleware-lab
for dep in kafka rabbitmq payment-bridge notification-worker; do
  kubectl -n "$NS" rollout status "deployment/$dep" --timeout=120s
done

ID="PAG-DUPLICADO-$(date -u +%Y%m%dT%H%M%S)-$RANDOM"
PAYLOAD=$(printf '{"pagamento_id":"%s","valor_centavos":1999,"status":"APROVADO_SIMULADO"}' "$ID")

echo "=== PUBLICANDO DUAS VEZES O MESMO EVENTO DE TESTE ==="
printf '%s\n%s\n' "$PAYLOAD" "$PAYLOAD" |
  kubectl -n "$NS" exec -i deployment/kafka -- \
    /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server kafka:9092 --topic pagamentos-simulados
echo "Mesmo pagamento_id publicado 2 vezes: $ID"

echo "=== AGUARDANDO BRIDGE E WORKER ==="
for n in $(seq 1 45); do
  BRIDGE=$(kubectl -n "$NS" logs deployment/payment-bridge --since=5m --tail=400 2>/dev/null || true)
  WORKER=$(kubectl -n "$NS" logs deployment/notification-worker --since=5m --tail=400 2>/dev/null || true)

  FORWARDED=$(printf '%s\n' "$BRIDGE" |
    awk -v id="$ID" 'index($0, "\"event\": \"FORWARDED\"") && index($0, id) {n++} END {print n+0}')
  ACKED=$(printf '%s\n' "$WORKER" |
    awk -v id="$ID" 'index($0, "\"event\": \"ACK\"") && index($0, id) {n++} END {print n+0}')

  if (( FORWARDED >= 2 && ACKED >= 2 )); then
    echo "Bridge: $FORWARDED publicações confirmadas no RabbitMQ."
    echo "Worker: $ACKED confirmações ACK do mesmo pagamento_id."
    printf '%s\n' "$WORKER" |
      grep -F '"event": "NOTIFICATION_PROCESSED"' | grep -F "$ID" || true
    echo "SUCESSO: duplicatas demonstradas; o Worker ainda não é idempotente."
    echo "PRÓXIMA AULA: deduplicar por pagamento_id e enviar mensagens inválidas para DLQ."
    exit 0
  fi
  sleep 2
done

echo "FALHA: não observamos ambas as entregas em 90 segundos."
echo "FORWARDED=$FORWARDED ACKED=$ACKED"
kubectl -n "$NS" get pods -o wide
kubectl -n "$NS" logs deployment/payment-bridge --tail=40 || true
kubectl -n "$NS" logs deployment/notification-worker --tail=40 || true
exit 1
