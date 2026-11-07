#!/usr/bin/env bash
# Testa rejeição de mensagem inválida pelo worker e armazenamento na DLQ.
set -euo pipefail
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=90s
kubectl -n "$NS" rollout status deployment/payment-bridge --timeout=90s
DLQ=notificacoes-pagamentos-dlq
echo "=== FILA DLQ ANTES ==="
kubectl -n "$NS" exec deployment/rabbitmq -- rabbitmqctl -q list_queues name messages_ready
BEFORE=$(kubectl -n "$NS" exec deployment/rabbitmq -- rabbitmqctl -q list_queues name messages_ready | awk -v q="$DLQ" '$1==q{print $2}')
[[ "$BEFORE" =~ ^[0-9]+$ ]] || { echo "ERRO: DLQ não existe." >&2; exit 1; }
ID="INVALIDO-$(date -u +%Y%m%dT%H%M%S)-$RANDOM"
# Publica payload JSON sintaticamente válido, porém sem pagamento_id.
# Python/pika já estão disponíveis no contêiner da Bridge.
kubectl -n "$NS" exec -i deployment/payment-bridge -- python - "$ID" <<'PY'
import os, sys, pika, json
c = pika.BlockingConnection(pika.ConnectionParameters(
    host="rabbitmq", credentials=pika.PlainCredentials("labuser", os.environ["RABBIT_PASSWORD"])))
ch = c.channel()
ch.confirm_delivery()
ch.basic_publish(exchange="", routing_key="notificacoes-pagamentos",
    body=json.dumps({"invalido_ref": sys.argv[1]}).encode(),
    properties=pika.BasicProperties(content_type="application/json"), mandatory=True)
c.close()
PY
echo "Payload sem pagamento_id enviado: $ID"
for _ in $(seq 1 30); do
  NOW=$(kubectl -n "$NS" exec deployment/rabbitmq -- rabbitmqctl -q list_queues name messages_ready | awk -v q="$DLQ" '$1==q{print $2}')
  if [[ "$NOW" =~ ^[0-9]+$ ]] && (( NOW > BEFORE )); then
    echo "DLQ antes=$BEFORE; depois=$NOW"
    echo "SUCESSO: payload inválido rejeitado e direcionado à DLQ."
    echo "AVISO: a fila DLQ preserva payloads para análise, não reprocessa automaticamente."
    exit 0
  fi
  sleep 2
done
echo "FALHA: tamanho da DLQ não aumentou."
kubectl -n "$NS" logs deployment/notification-worker --tail=40 || true
exit 1
