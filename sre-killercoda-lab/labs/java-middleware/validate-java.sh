#!/usr/bin/env bash
# Validacao com consultas HTTP; nao altera workloads.
set -euo pipefail
NS=sre-java-lab
echo "=== COMPONENTES ==="
kubectl -n "$NS" get pods,svc,deploy -o wide
echo "=== APACHE -> TOMCAT (JSP JAVA) ==="
kubectl -n "$NS" exec deployment/apache-gateway -- sh -c 'wget -qO - http://127.0.0.1/tomcat/index.jsp'
if kubectl -n "$NS" get deployment wildfly-app >/dev/null 2>&1; then
  echo "=== APACHE -> WILDFLY (JSP JAVA) ==="
  kubectl -n "$NS" exec deployment/apache-gateway -- sh -c 'wget -qO - http://127.0.0.1/wildfly/index.jsp'
else
  echo "WILDFLY: nao instalado, teste ignorado."
fi
echo "VALIDACAO: consultas HTTP realizadas pelo Apache dentro do cluster."
