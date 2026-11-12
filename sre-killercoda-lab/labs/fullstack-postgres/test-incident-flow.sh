#!/usr/bin/env bash
# Teste de escrita intencional: cria incidente fictício e atualiza seu estado no DB.
set -euo pipefail
NS=sre-fullstack-lab
kubectl -n "$NS" exec -i deployment/incidents-api -- python - <<'PY'
import json
from urllib.request import Request, urlopen

base = "http://incidents-web"
body = {
    "service": "api-pagamentos-lab",
    "severity": "P2",
    "description": "Teste SRE: lentidão sintética frontend/backend",
}
req = Request(
    base + "/api/incidents",
    data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json"},
    method="POST",
)
with urlopen(req, timeout=10) as resp:
    result = json.load(resp)
    assert resp.status == 201
incident_id = result["id"]
print("Criado incidente ID:", incident_id)

req = Request(
    base + "/api/incidents/" + str(incident_id),
    data=json.dumps({"status": "INVESTIGATING"}).encode(),
    headers={"Content-Type": "application/json"},
    method="PATCH",
)
with urlopen(req, timeout=10) as resp:
    result = json.load(resp)
    assert result["status"] == "INVESTIGATING"
print("Estado atualizado:", result)

with urlopen(base + "/api/incidents", timeout=10) as resp:
    result = json.load(resp)
    item = next((i for i in result["items"] if i["id"] == incident_id), None)
    assert item is not None and item["status"] == "INVESTIGATING", result
print("SUCESSO: Front Nginx -> API Python -> PostgreSQL, com escrita/leitura comprovada.")
PY
