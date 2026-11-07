#!/usr/bin/env bash
# Validação de métricas ao vivo com pagamentos e notificações FICTÍCIAS.
# Não instala Prometheus/Grafana nem altera segredos ou sistemas externos.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/notification-worker --timeout=90s

read_metric() {
  local key="$1"
  kubectl -n "$NS" exec deployment/notification-worker -- python -c \
    'import urllib.request; print(urllib.request.urlopen("http://127.0.0.1:9100/metrics", timeout=5).read().decode())' |
    awk -v key="$key" '$1 == key {print $2; found=1; exit} END {if (!found) exit 1}'
}

echo "=== MÉTRICAS ANTES DOS EVENTOS ==="
BEFORE_PROCESSED=$(read_metric sre_notification_processed_total)
BEFORE_DUP=$(read_metric sre_notification_duplicate_skipped_total)
BEFORE_ACK=$(read_metric sre_notification_ack_total)
BEFORE_INVALID=$(read_metric sre_notification_invalid_total)
printf 'processed=%s duplicate=%s ack=%s invalid=%s\n' "$BEFORE_PROCESSED" "$BEFORE_DUP" "$BEFORE_ACK" "$BEFORE_INVALID"

echo "=== TESTE DE EVENTOS IDÊNTICOS (2 entregas, 1 processamento) ==="
bash labs/test-idempotencia.sh

echo "=== TESTE DE NOTIFICAÇÃO INVÁLIDA / DLQ ==="
bash labs/test-dlq.sh

echo "=== MÉTRICAS DEPOIS DOS EVENTOS ==="
AFTER_PROCESSED=$(read_metric sre_notification_processed_total)
AFTER_DUP=$(read_metric sre_notification_duplicate_skipped_total)
AFTER_ACK=$(read_metric sre_notification_ack_total)
AFTER_INVALID=$(read_metric sre_notification_invalid_total)
printf 'processed=%s duplicate=%s ack=%s invalid=%s\n' "$AFTER_PROCESSED" "$AFTER_DUP" "$AFTER_ACK" "$AFTER_INVALID"

if (( AFTER_PROCESSED - BEFORE_PROCESSED < 1 ||
      AFTER_DUP - BEFORE_DUP < 1 ||
      AFTER_ACK - BEFORE_ACK < 2 ||
      AFTER_INVALID - BEFORE_INVALID < 1 )); then
  echo "FALHA: contadores não evoluíram como esperado. Confira restart dos Pods e logs." >&2
  kubectl -n "$NS" get pods -l app=notification-worker -o wide
  exit 1
fi

echo "=== CONECTIVIDADE SERVICE /metrics ==="
kubectl -n "$NS" exec deployment/payment-bridge -- python -c \
  'import urllib.request; u="http://notification-worker-metrics:9100/metrics"; d=urllib.request.urlopen(u,timeout=5).read().decode(); assert "sre_notification_processed_total" in d; print("HTTP OK no Service:",u)'
echo "SUCESSO: métricas aumentaram com processamento, duplicata, ACK e DLQ."
echo "Nota: counters são por processo e reiniciam após restart do Worker."
