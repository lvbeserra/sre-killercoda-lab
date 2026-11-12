#!/usr/bin/env bash
# Instala módulo opcional PostgreSQL + Python API + Nginx no KillerCoda.
# Não modifica workloads de outros namespaces.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
NS=sre-fullstack-lab

for cmd in kubectl python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: comando obrigatório ausente: $cmd" >&2
    exit 2
  fi
done
kubectl cluster-info >/dev/null
kubectl apply -f "$DIR/namespace.yaml"

if kubectl -n "$NS" get secret pg-lab-credentials >/dev/null 2>&1; then
  echo "Credenciais PostgreSQL já existentes: preservadas (não serão regeneradas)."
else
  echo "Criando Secret Kubernetes com senha aleatória (sem gravar no Git)..."
  PASSWORD="$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')"
  kubectl -n "$NS" create secret generic pg-lab-credentials \
    --from-literal=POSTGRES_USER=labuser \
    --from-literal=POSTGRES_DB=srelab \
    --from-literal=POSTGRES_PASSWORD="$PASSWORD" >/dev/null
  unset PASSWORD
  echo "Secret criada. Não cole seu conteúdo em chats ou repositórios."
fi

echo "Atualizando código, SQL e Nginx em ConfigMaps..."
kubectl -n "$NS" create configmap pg-schema \
  --from-file=schema.sql="$DIR/schema.sql" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create configmap incidents-api-code \
  --from-file=server.py="$DIR/server.py" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create configmap incidents-web-html \
  --from-file=index.html="$DIR/index.html" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create configmap incidents-web-config \
  --from-file=nginx.conf="$DIR/nginx.conf" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Aplicando PostgreSQL, API e frontend..."
kubectl apply -f "$DIR/resources.yaml"

echo "Validando PostgreSQL..."
kubectl -n "$NS" rollout status statefulset/postgres --timeout=240s
echo "Validando backend Python (instala psycopg na primeira subida)..."
kubectl -n "$NS" rollout status deployment/incidents-api --timeout=300s
echo "Validando frontend Nginx..."
kubectl -n "$NS" rollout status deployment/incidents-web --timeout=180s

echo
echo "=== COMPONENTES ==="
kubectl -n "$NS" get pods,svc,pvc -o wide
echo
echo "A instalacao K8s foi solicitada; execute validate-fullstack.sh para teste funcional."
echo "Para abrir a interface no navegador, confira README.md deste modulo."
