#!/usr/bin/env bash
# Aula SRE: amostragem sintética de SLI HTTP e latência (sem stack adicional).
# Este teste faz 20 checagens por endpoint dentro do Pod payment-bridge.
# Não confundir esta amostra com SLO real de 30 dias.
set -euo pipefail
NS=sre-middleware-lab

for dep in apache payment-bridge notification-worker; do
  kubectl -n "$NS" rollout status "deployment/$dep" --timeout=120s
done

echo "=== SLI SINTETICO: APACHE E ENDPOINT PROMETHEUS ==="
kubectl -n "$NS" exec -i deployment/payment-bridge -- python - <<'PY'
import json
import math
import time
import urllib.error
import urllib.request

TARGETS = {
    "apache_http": ("http://apache.sre-middleware-lab.svc.cluster.local/", b"SRE Middleware Lab"),
    "notification_metrics": (
        "http://notification-worker-metrics.sre-middleware-lab.svc.cluster.local:9100/metrics",
        b"sre_notification_processed_total",
    ),
}
SAMPLES = 20
results = {}

for name, (url, expected) in TARGETS.items():
    latencies_ms = []
    failures = []
    for attempt in range(1, SAMPLES + 1):
        started = time.perf_counter()
        try:
            with urllib.request.urlopen(url, timeout=3) as response:
                body = response.read(65536)
                http_ok = 200 <= response.status < 300
                if not http_ok or expected not in body:
                    raise ValueError(f"unexpected_status_or_body status={response.status}")
            latencies_ms.append((time.perf_counter() - started) * 1000)
        except Exception as exc:
            failures.append({"attempt": attempt, "reason": str(exc)})
        time.sleep(0.1)

    success = len(latencies_ms)
    availability = success / SAMPLES * 100.0
    ordered = sorted(latencies_ms)
    p50 = ordered[math.ceil(len(ordered) * 0.50) - 1] if ordered else None
    p95 = ordered[math.ceil(len(ordered) * 0.95) - 1] if ordered else None
    results[name] = {
        "success": success,
        "total": SAMPLES,
        "availability_sample_percent": round(availability, 2),
        "p50_success_ms": round(p50, 1) if p50 is not None else None,
        "p95_success_ms": round(p95, 1) if p95 is not None else None,
        "failures": failures,
    }

print(json.dumps({"kind": "SRE_SYNTHETIC_SNAPSHOT", "results": results}, indent=2))
if all(item["success"] == SAMPLES for item in results.values()):
    print("SUCESSO: todos os endpoints responderam nas 20 tentativas.")
else:
    print("ALERTA: pelo menos uma tentativa falhou; revisar os detalhes.")
    raise SystemExit(1)
PY

echo "=== LIMITACAO DE MEDICAO ==="
echo "Amostra de 20 tentativas por endpoint, sem serie historica e sem usuarios reais."
echo "O SLO didatico de 99,9% em 30 dias NAO pode ser validado por este snapshot."
echo "Métricas de processo reiniciam com o Pod; para SLO real usar coleta durável."
