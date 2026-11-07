#!/usr/bin/env bash
# LAB ONLY: simula indisponibilidade do Apache, registra falha no observador
# e restaura o Deployment. Não afeta RabbitMQ, Kafka ou dados financeiros.
set -euo pipefail
NS=sre-middleware-lab
ORIGINAL=$(kubectl -n "$NS" get deployment/apache -o jsonpath='{.spec.replicas}')
if [[ "$ORIGINAL" != "1" ]]; then
  echo "ABORTADO: esperada 1 réplica do Apache, encontrei '$ORIGINAL'." >&2
  exit 2
fi
kubectl -n "$NS" rollout status deployment/sre-observer --timeout=90s
kubectl -n "$NS" rollout status deployment/apache --timeout=90s
RESTORE=0

recover() {
  if [[ "$RESTORE" == "1" ]]; then
    echo "Restaurando Apache para 1 réplica (cleanup automático)..."
    kubectl -n "$NS" scale deployment/apache --replicas=1 || true
  fi
}
trap recover EXIT

echo "=== 1. INDISPONIBILIZANDO APACHE TEMPORARIAMENTE ==="
RESTORE=1
kubectl -n "$NS" scale deployment/apache --replicas=0
kubectl -n "$NS" wait --for=delete pod -l app=apache --timeout=90s
echo "=== 2. COLETANDO FALHA SINTÉTICA ==="
kubectl -n "$NS" exec deployment/sre-observer -- python /app/collector.py once
kubectl -n "$NS" exec deployment/sre-observer -- python -c \
  'import sqlite3; d=sqlite3.connect("/data/observations.sqlite3"); x=d.execute("SELECT success,error FROM samples WHERE service=? ORDER BY rowid DESC LIMIT 1",("apache_http",)).fetchone(); print("Ultima amostra Apache:",x); assert x is not None and x[0] == 0, "Falha Apache nao foi registrada"'

echo "=== 3. RESTAURANDO APACHE ==="
kubectl -n "$NS" scale deployment/apache --replicas=1
kubectl -n "$NS" rollout status deployment/apache --timeout=120s
RESTORE=0
echo "=== 4. COLETANDO RECUPERAÇÃO ==="
kubectl -n "$NS" exec deployment/sre-observer -- python /app/collector.py once
kubectl -n "$NS" exec deployment/sre-observer -- python -c \
  'import sqlite3; d=sqlite3.connect("/data/observations.sqlite3"); x=d.execute("SELECT success,latency_ms FROM samples WHERE service=? ORDER BY rowid DESC LIMIT 1",("apache_http",)).fetchone(); print("Ultima amostra Apache:",x); assert x is not None and x[0] == 1, "Recuperacao Apache nao foi registrada"'

echo "=== 5. RELATÓRIO DO HISTÓRICO ==="
kubectl -n "$NS" exec deployment/sre-observer -- \
  python /app/collector.py report --window-minutes 5

echo "SUCESSO: indisponibilidade e recuperação sintéticas registradas no SQLite."
echo "ATENÇÃO: disponibilidade amostral não é SLO real de 30 dias."
