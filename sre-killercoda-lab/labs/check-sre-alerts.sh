#!/usr/bin/env bash
# Aula SRE: checagem pontual de alertas, sem Prometheus/Alertmanager.
# Somente pagamentos FICTICIOS. Retornos: 0 OK, 1 WARNING, 2 CRITICAL.
set -uo pipefail
NS=sre-middleware-lab
SEVERITY=0
warning() {
  echo "WARNING: $*"
  if (( SEVERITY < 1 )); then SEVERITY=1; fi
  return 0
}
critical() {
  echo "CRITICAL: $*"
  SEVERITY=2
  return 0
}

echo "=== HEALTH CHECK: DEPLOYMENTS ==="
for dep in kafka rabbitmq payment-bridge notification-worker; do
  if ! DATA=$(kubectl -n "$NS" get deployment "$dep" -o jsonpath='{.spec.replicas} {.status.readyReplicas}' 2>/dev/null); then
    critical "Deployment $dep nao encontrado ou inacessivel"
    continue
  fi
  DESIRED=$(printf '%s\n' "$DATA" | awk '{print $1}')
  READY=$(printf '%s\n' "$DATA" | awk '{print $2}')
  if [[ ! "$DESIRED" =~ ^[0-9]+$ || ! "$READY" =~ ^[0-9]+$ ]]; then
    critical "Estado invalido do Deployment $dep: $DATA"
  elif (( DESIRED < 1 || READY < DESIRED )); then
    critical "$dep: replicas prontas $READY/$DESIRED"
  else
    echo "OK: $dep $READY/$DESIRED Ready"
  fi
done

echo "=== SCRAPE DOS CONTADORES PROMETHEUS ==="
if METRICS=$(kubectl -n "$NS" exec deployment/notification-worker -- python -c \
  'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:9100/metrics", timeout=6).read().decode())' 2>/dev/null); then
  printf '%s\n' "$METRICS" |
    awk '$1 ~ /^sre_notification_(processed|duplicate_skipped|invalid|ack|db_error|reconnect)_total$/ {print $1 "=" $2}'
  if ! printf '%s\n' "$METRICS" | grep -q '^sre_notification_processed_total '; then
    critical "Endpoint respondeu sem metricas esperadas"
  fi
else
  critical "Scrape /metrics indisponivel"
fi

echo "=== BACKLOG RABBITMQ ==="
if QUEUES=$(kubectl -n "$NS" exec deployment/rabbitmq -- \
  rabbitmqctl -q list_queues name messages_ready messages_unacknowledged 2>/dev/null); then
  printf '%s\n' "$QUEUES"
  MAIN=$(printf '%s\n' "$QUEUES" | awk '$1=="notificacoes-pagamentos" {print $2}')
  UNACK=$(printf '%s\n' "$QUEUES" | awk '$1=="notificacoes-pagamentos" {print $3}')
  DLQ=$(printf '%s\n' "$QUEUES" | awk '$1=="notificacoes-pagamentos-dlq" {print $2}')
  if [[ ! "$MAIN" =~ ^[0-9]+$ || ! "$UNACK" =~ ^[0-9]+$ || ! "$DLQ" =~ ^[0-9]+$ ]]; then
    critical "Fila principal ou DLQ ausente/inacessivel"
  else
    if (( DLQ > 0 )); then warning "DLQ com $DLQ mensagem(ns) a analisar"; fi
    if (( MAIN >= 10 )); then warning "Backlog com $MAIN mensagem(ns) prontas (limiar 10)"; fi
    if (( UNACK >= 10 )); then warning "$UNACK mensagem(ns) sem ACK (limiar 10)"; fi
  fi
else
  critical "Nao foi possivel consultar filas RabbitMQ"
fi

echo "=== VEREDITO ==="
case "$SEVERITY" in
  0) echo "OK: nenhum alerta disparou nesta verificacao" ;;
  1) echo "WARNING: revisar filas e mensagens pendentes" ;;
  *) echo "CRITICAL: servico ou metricas indisponiveis" ;;
esac
echo "Nota: snapshot pontual nao substitui Prometheus/Alertmanager nem SLO de janela."
exit "$SEVERITY"
