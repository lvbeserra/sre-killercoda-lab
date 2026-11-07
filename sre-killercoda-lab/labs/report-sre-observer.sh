#!/usr/bin/env bash
set -euo pipefail
WINDOW="${1:-5}"
if [[ ! "$WINDOW" =~ ^[0-9]+$ ]] || (( WINDOW == 0 )); then
  echo "Uso: bash labs/report-sre-observer.sh [JANELA_MINUTOS > 0]" >&2
  exit 2
fi
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/sre-observer --timeout=60s
kubectl -n "$NS" exec deployment/sre-observer -- \
  python /app/collector.py report --window-minutes "$WINDOW"
