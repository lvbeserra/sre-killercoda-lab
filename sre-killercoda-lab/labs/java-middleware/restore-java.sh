#!/usr/bin/env bash
# Laboratorio ISOLADO Apache HTTP Server + Tomcat, opcional WildFly.
# O bootstrap padrao nao executa este modulo para evitar falta de RAM.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
NS=sre-java-lab
MODE=base
if [[ $# -gt 0 ]]; then MODE="$1"; fi
if [[ "$MODE" != base && "$MODE" != --with-wildfly ]]; then
  echo "USO: bash $0 [--with-wildfly]" >&2
  exit 2
fi
command -v kubectl >/dev/null || { echo "Ausente: kubectl" >&2; exit 2; }
kubectl cluster-info >/dev/null
echo "=== APLICANDO NAMESPACE E CONFIGURACOES ==="
kubectl apply -f "$DIR/namespace.yaml"
kubectl -n "$NS" create configmap java-lab-jsp --from-file=index.jsp="$DIR/app/index.jsp" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create configmap java-lab-apache-conf --from-file=apache-proxy.conf="$DIR/apache-proxy.conf" --dry-run=client -o yaml | kubectl apply -f -

echo "=== TOMCAT + APACHE HTTP SERVER ==="
kubectl apply -f "$DIR/base.yaml"
kubectl -n "$NS" rollout status deployment/tomcat-app --timeout=300s
kubectl -n "$NS" rollout status deployment/apache-gateway --timeout=180s

if [[ "$MODE" == --with-wildfly ]]; then
  echo "=== WILDFLY (opcional / exige memoria extra) ==="
  kubectl apply -f "$DIR/wildfly.yaml"
  # A instancia pode ter sido pausada com kubectl scale --replicas=0 apos CrashLoopBackOff.
  # Garante que a recuperacao do laboratorio realmente coloque um Pod no ar.
  kubectl -n "$NS" scale deployment/wildfly-app --replicas=1
  kubectl -n "$NS" rollout status deployment/wildfly-app --timeout=420s
else
  echo "WildFly nao iniciado. Para inclui-lo: bash $0 --with-wildfly"
fi

echo "=== RECURSOS ==="
kubectl -n "$NS" get pods,deploy,svc -o wide
echo "=== TESTE HTTP DO PROXY PARA TOMCAT ==="
kubectl -n "$NS" exec deployment/apache-gateway -- sh -c 'wget -qO - http://127.0.0.1/tomcat/index.jsp'
if [[ "$MODE" == --with-wildfly ]]; then
  echo "=== TESTE HTTP DO PROXY PARA WILDFLY ==="
  kubectl -n "$NS" exec deployment/apache-gateway -- sh -c 'wget -qO - http://127.0.0.1/wildfly/index.jsp'
fi
echo "SUCESSO: fluxo(s) validado(s). Nenhuma porta foi exposta externamente."
echo "UI opcional (apenas lab): kubectl -n $NS port-forward svc/apache-gateway 8090:80"
