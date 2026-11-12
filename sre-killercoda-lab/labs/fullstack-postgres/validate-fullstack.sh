#!/usr/bin/env bash
# Validação funcional read-only do módulo Full Stack.
set -euo pipefail
NS=sre-fullstack-lab
echo "=== PODS, SERVICE E PERSISTENCIA ==="
kubectl -n "$NS" get pods,svc,pvc -o wide
echo
echo "=== SQL: STATUS E NUMERO DE INCIDENTES ==="
kubectl -n "$NS" exec postgres-0 -- sh -c \
  'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT current_database(), count(*) FROM incidents;"'
echo
echo "=== API REST VIA NGINX (HTTPS NÃO CONFIGURADO: somente laboratório) ==="
kubectl -n "$NS" exec deployment/incidents-api -- python -c \
  'import urllib.request; u="http://incidents-web/api/health"; print(u, urllib.request.urlopen(u, timeout=10).read().decode())'
kubectl -n "$NS" exec deployment/incidents-api -- python -c \
  'import urllib.request; u="http://incidents-web/api/incidents"; print(u, urllib.request.urlopen(u, timeout=10).read().decode()[:700])'
echo
echo "=== METRICAS DA API ==="
kubectl -n "$NS" exec deployment/incidents-api -- python -c \
  'import urllib.request; print(urllib.request.urlopen("http://incidents-web/metrics",timeout=10).read().decode()[:700])'
echo
echo "SUCESSO: banco, API e proxy web responderam. Abra o frontend para verificar a interface."
