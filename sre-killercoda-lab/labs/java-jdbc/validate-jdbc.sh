#!/usr/bin/env bash
# Validacao funcional read-only; exige pg + java-jdbc.
set -euo pipefail
NS=sre-fullstack-lab
echo "=== JAVA JDBC (DEPLOYMENT/SERVICE) ==="
kubectl -n "$NS" get deploy,pods,svc -l app=java-jdbc -o wide
echo "=== HEALTH JSP / JDBC / POSTGRESQL (GET, SELECT COUNT) ==="
kubectl -n "$NS" exec deployment/incidents-api -- python -c \
 'import urllib.request; u="http://java-jdbc:8080/java-jdbc/index.jsp"; r=urllib.request.urlopen(u,timeout=15); b=r.read().decode(); print("HTTP",r.status); print(b); assert "SRE Java JDBC Lab" in b and "Status: OK" in b'
echo "=== POSTGRESQL BASE ==="
kubectl -n "$NS" exec postgres-0 -- sh -c \
 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atqc "SELECT current_database(), count(*) FROM incidents;"'
echo "SUCESSO: WAR, JDBC e PostgreSQL validados."
