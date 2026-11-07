#!/usr/bin/env bash
# E2E: publica 1 pagamento FICTICIO no Kafka e verifica encaminhamento pelo bridge ao RabbitMQ.
set -euo pipefail
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=180s
ID="PAG-BRIDGE-$(date -u +%Y%m%dT%H%M%SZ)"
MSG=$(printf '{"pagamento_id":"%s","valor_centavos":1575,"status":"APROVADO_SIMULADO"}' "$ID")
printf '%s\n' "$MSG" | kubectl -n "$NS" exec -i deploy/kafka -- \
  /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --topic pagamentos-simulados
echo "Publicação Kafka: $ID"
echo "Aguardando evidência de encaminhamento nos logs da bridge..."
OK=0
for i in $(seq 1 30); do
  LOG=$(kubectl -n "$NS" logs deploy/payment-bridge --since=3m --tail=100 2>/dev/null || true)
  if printf '%s\n' "$LOG" | grep -F '"event": "FORWARDED"' | grep -Fq "$ID"; then
    echo "BRIDGE encaminhou com confirmação e commit Kafka:"
    printf '%s\n' "$LOG" | grep -F '"event": "FORWARDED"' | grep -F "$ID" | tail -1
    OK=1
    break
  fi
  sleep 2
done
if [[ $OK -ne 1 ]]; then
  echo "FALHA: não encontrei confirmação de encaminhamento em até 60 segundos."
  kubectl -n "$NS" logs deploy/payment-bridge --tail=50 || true
  exit 1
fi
echo "A mensagem foi publicada na fila RabbitMQ pelo bridge (publisher confirm)."
echo "Aula seguinte: validar leitura/ACK na fila e implantar o notification-worker."
echo "SUCESSO: Fluxo Kafka -> bridge -> RabbitMQ validado por logs da bridge."
