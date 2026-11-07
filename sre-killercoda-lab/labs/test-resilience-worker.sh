#!/usr/bin/env bash
# Laboratório controlado: indisponibilizar somente o consumidor RabbitMQ (Worker),
# publicar UM evento fictício, verificar fila e restaurar o Worker para obter ACK.
# NÃO executar em ambientes reais de pagamentos.
set -euo pipefail

NS=sre-middleware-lab
for dep in kafka rabbitmq payment-bridge notification-worker; do
  kubectl -n "$NS" rollout status "deployment/$dep" --timeout=120s
done
ORIGINAL=$(kubectl -n "$NS" get deployment notification-worker -o jsonpath='{.spec.replicas}')
if [[ "$ORIGINAL" != "1" ]]; then
  echo "ABORTADO: esperado exatamente 1 replica do Worker; atual=$ORIGINAL." >&2
  exit 1
fi

WORKER_STOPPED=0
restore_worker() {
  if [[ "$WORKER_STOPPED" == "1" ]]; then
    echo "Restaurando notification-worker para $ORIGINAL replica(s)..."
    kubectl -n "$NS" scale deployment/notification-worker --replicas="$ORIGINAL" || true
  fi
}
trap restore_worker EXIT INT TERM

echo "=== ETAPA 1: PARAR APENAS O WORKER ==="
kubectl -n "$NS" scale deployment/notification-worker --replicas=0
WORKER_STOPPED=1
# Espera o Pod ser removido antes de criar a nova mensagem.
STOPPED=0
for _ in $(seq 1 45); do
  COUNT=$(kubectl -n "$NS" get pods -l app=notification-worker -o jsonpath='{.items[*].metadata.name}' | wc -w)
  if [[ "$COUNT" == "0" ]]; then STOPPED=1; break; fi
  sleep 2
done
if [[ "$STOPPED" != "1" ]]; then
  echo "FALHA: Worker não terminou no prazo de 90 segundos." >&2
  exit 1
fi
echo "Worker zerado. Kafka, Bridge e RabbitMQ continuam ativos."

echo "=== ETAPA 2: PRODUZIR PAGAMENTO SIMULADO ==="
ID="PAG-RESILIENCIA-$(date -u +%Y%m%dT%H%M%S)-$RANDOM"
MSG=$(printf '{"pagamento_id":"%s","valor_centavos":4321,"status":"APROVADO_SIMULADO"}' "$ID")
printf '%s\n' "$MSG" |
  kubectl -n "$NS" exec -i deployment/kafka -- \
    /opt/kafka/bin/kafka-console-producer.sh \
      --bootstrap-server kafka:9092 --topic pagamentos-simulados
echo "Pagamento fictício enviado: $ID"

echo "=== ETAPA 3: CONFIRMAR ENCAMINHAMENTO PARA FILA RABBITMQ ==="
FORWARDED=0
for _ in $(seq 1 30); do
  LOG=$(kubectl -n "$NS" logs deployment/payment-bridge --since=5m --tail=200 2>/dev/null || true)
  if printf '%s\n' "$LOG" | grep -F '"event": "FORWARDED"' | grep -Fq "$ID"; then
    FORWARDED=1
    printf '%s\n' "$LOG" | grep -F '"event": "FORWARDED"' | grep -F "$ID" | tail -1
    break
  fi
  sleep 2
done
if [[ "$FORWARDED" != "1" ]]; then
  echo "FALHA: não houve confirmação da Bridge em 60 segundos." >&2
  exit 1
fi
echo "Fila enquanto o consumidor está parado:"
kubectl -n "$NS" exec deployment/rabbitmq -- \
  rabbitmqctl -q list_queues name messages_ready messages_unacknowledged || true

echo "=== ETAPA 4: RECUPERAR O WORKER E CONFERIR ACK ==="
kubectl -n "$NS" scale deployment/notification-worker --replicas="$ORIGINAL"
WORKER_STOPPED=0
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=180s
ACKED=0
for _ in $(seq 1 40); do
  LOG=$(kubectl -n "$NS" logs deployment/notification-worker --since=5m --tail=200 2>/dev/null || true)
  if printf '%s\n' "$LOG" | grep -F '"event": "ACK"' | grep -Fq "$ID"; then
    ACKED=1
    printf '%s\n' "$LOG" | grep -F '"event": "ACK"' | grep -F "$ID" | tail -1
    break
  fi
  sleep 2
done
if [[ "$ACKED" != "1" ]]; then
  echo "FALHA: sem ACK do Worker no prazo, verificar logs RabbitMQ/Worker." >&2
  exit 1
fi
echo "Filas após recuperação:"
kubectl -n "$NS" exec deployment/rabbitmq -- \
  rabbitmqctl -q list_queues name messages_ready messages_unacknowledged || true
echo "SUCESSO: fila reteve notificação com Worker parado; processamento e ACK após retorno."
echo "AVISO: isso não testa perda do broker: volumes emptyDir desaparecem quando o Pod é removido."
