#!/usr/bin/env bash
# Módulo opcional: WAR Tomcat + PostgreSQL JDBC. Isolado e SOMENTE SELECT.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
NS=sre-fullstack-lab

command -v kubectl >/dev/null || { echo "ERRO: kubectl ausente" >&2; exit 2; }
kubectl cluster-info >/dev/null
kubectl -n "$NS" get secret pg-lab-credentials >/dev/null || {
  echo "ERRO: Secret pg-lab-credentials ausente. Restaure antes o fullstack-postgres." >&2
  exit 2
}
kubectl -n "$NS" rollout status statefulset/postgres --timeout=180s
echo "=== PUBLICANDO CODIGO DA PAGINA JDBC (SEM SENHA NO GIT) ==="
kubectl -n "$NS" create configmap java-jdbc-source \
  --from-file=index.jsp="$DIR/index.jsp" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "=== APLICANDO WAR JAVA COMO MODULO OPCIONAL ==="
kubectl apply -f "$DIR/resources.yaml"
kubectl -n "$NS" rollout status deployment/java-jdbc --timeout=300s
echo "=== ESTADO ==="
kubectl -n "$NS" get pods,svc -l app=java-jdbc -o wide
echo "=== TESTE HTTP JSP -> JDBC -> PostgreSQL ==="
kubectl -n "$NS" exec deployment/incidents-api -- python -c \
 'import urllib.request; u="http://java-jdbc:8080/java-jdbc/index.jsp"; print(urllib.request.urlopen(u,timeout=15).read().decode())'
echo "APROVADO: WAR e JDBC read-only."
