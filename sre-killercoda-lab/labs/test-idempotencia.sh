#!/usr/bin/env bash
# Confirma que duas entregas com o MESMO ID são ACKadas mas só processadas uma vez.
# Pagamentos fictícios, sem efeito financeiro.
set -euo pipefail
NS=sre-middleware-lab
for dep in kafka rabbitmq payment-bridge notification-worker; do
  kubectl -n "$NS" rollout status "deployment/$dep" --timeout=120s
done
ID="PAG-IDEMP-$(date -u +%Y%m%dT%H%M%S)-$RANDOM"
PAYLOAD=$(printf '{"pagamento_id":"%s","valor_centavos":1999,"status":"APROVADO_SIMULADO"}' "$ID")
printf '%s\n%s\n' "$PAYLOAD" "$PAYLOAD" |
  kubectl -n "$NS" exec -i deployment/kafka -- \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic pagamentos-simulados
echo "Teste de idempotência, ID: $ID"
for _ in $(seq 1 45); do
  BRIDGE=$(kubectl -n "$NS" logs deployment/payment-bridge --since=5m --tail=400 2>/dev/null || true)
  WORKER=$(kubectl -n "$NS" logs deployment/notification-worker --since=5m --tail=400 2>/dev/null || true)
  FW=$(printf '%s\n' "$BRIDGE" | awk -v id="$ID" 'index($0, "\"event\": \"FORWARDED\"") && index($0, id){n++} END{print n+0}')
  ACK=$(printf '%s\n' "$WORKER" | awk -v id="$ID" 'index($0, "\"event\": \"ACK\"") && index($0, id){n++} END{print n+0}')
  DONE=$(printf '%s\n' "$WORKER" | awk -v id="$ID" 'index($0, "\"event\": \"NOTIFICATION_PROCESSED\"") && index($0, id){n++} END{print n+0}')
  DUP=$(printf '%s\n' "$WORKER" | awk -v id="$ID" 'index($0, "\"event\": \"DUPLICATE_SKIPPED\"") && index($0, id){n++} END{print n+0}')
  if (( FW >= 2 && ACK >= 2 && DONE == 1 && DUP >= 1 )); then
    echo "FORWARDED=$FW ACK=$ACK PROCESSED=$DONE DUPLICATE_SKIPPED=$DUP"
    printf '%s\n' "$WORKER" | grep -F "$ID" | tail -5
    echo "SUCESSO: duas entregas, um processamento; duplicata ignorada."
    exit 0
  fi
  sleep 2
done
echo "FALHA: FW=$FW ACK=$ACK PROCESSED=$DONE DUPLICATE_SKIPPED=$DUP"
kubectl -n "$NS" logs deployment/notification-worker --tail=35 || true
exit 1
