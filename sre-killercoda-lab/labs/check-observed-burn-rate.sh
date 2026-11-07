#!/usr/bin/env bash
# SRE KillerCoda LAB: avalia burn-rate a partir de histórico SINTÉTICO observado.
# Não aciona pagers, não agenda execução, não substitui SLO real de clientes.
set -euo pipefail
NS=sre-middleware-lab
kubectl -n "$NS" rollout status deployment/sre-observer --timeout=60s

kubectl -n "$NS" exec -i deployment/sre-observer -- python - <<'PY'
import json
import math
import os
import sqlite3
import time

DB = os.getenv("SRE_OBSERVER_DB", "/data/observations.sqlite3")
INTERVAL = max(10, int(os.getenv("SRE_OBSERVER_INTERVAL_SECONDS", "30")))
NOW = int(time.time())
BUDGET = 0.001
SERVICES = ("apache_http", "notification_metrics")
WINDOWS = {"5m": 300, "1h": 3600, "30m": 1800, "6h": 21600}
RULES = (
    ("PAGE_FAST", "1h", "5m", 14.4),
    ("PAGE_SUSTAINED", "6h", "30m", 6.0),
)

db = sqlite3.connect(DB)
try:
    tables = {r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type='table'"
    )}
    if "samples" not in tables:
        raise SystemExit("ERRO: banco ainda nao possui tabela samples")
    output = {"kind": "OBSERVED_SYNTHETIC_BURN_RATE", "time_utc_epoch": NOW, "services": {}}

    for service in SERVICES:
        stats = {}
        for label, seconds in WINDOWS.items():
            total, failed, first_ts, last_ts = db.execute(
                "SELECT count(*), coalesce(sum(CASE WHEN success=0 THEN 1 ELSE 0 END),0), "
                "min(ts), max(ts) FROM samples "
                "WHERE service=? AND ts>? AND ts<=?",
                (service, NOW - seconds, NOW),
            ).fetchone()
            span = (last_ts - first_ts) if total >= 2 else 0
            lag = (NOW - last_ts) if last_ts is not None else None
            # Cobertura temporal + mínimo de pontos para evitar janelas artificiais
            # com apenas duas amostras isoladas nas extremidades.
            expected = math.ceil(seconds / INTERVAL)
            enough = (
                total >= max(2, math.ceil(expected * 0.7))
                and span >= seconds * 0.9
                and lag is not None
                and lag <= INTERVAL * 2
            )
            burn = round((failed / total) / BUDGET, 2) if total else None
            stats[label] = {
                "requests_sampled": total,
                "failures": failed,
                "coverage_seconds": span,
                "last_sample_age_seconds": lag,
                "window_covered": enough,
                "burn_rate": burn,
            }

        alerts = []
        unresolved = []
        for alert_name, long_window, short_window, threshold in RULES:
            longer, shorter = stats[long_window], stats[short_window]
            if not longer["window_covered"] or not shorter["window_covered"]:
                unresolved.append(alert_name)
                continue
            if (longer["burn_rate"] > threshold and
                    shorter["burn_rate"] > threshold):
                alerts.append(alert_name)

        short = stats["5m"]
        if alerts:
            verdict = "PAGE_CANDIDATE_SYNTHETIC"
        elif unresolved:
            verdict = (
                "SHORT_WINDOW_WARNING_HISTORY_INCOMPLETE"
                if short["window_covered"] and short["burn_rate"] is not None
                   and short["burn_rate"] > 14.4
                else "INSUFFICIENT_HISTORY_FOR_PAGING"
            )
        else:
            verdict = "NO_PAGE"

        output["services"][service] = {
            "windows": stats,
            "candidate_alerts": alerts,
            "not_evaluated_rules": unresolved,
            "verdict": verdict,
        }

    print(json.dumps(output, indent=2, ensure_ascii=False))
    print()
    print("ATENCAO: avaliacao pontual de probes INTERNOS. Sem alerta remoto ou SLO real.")
    print("Uma janela nao coberta impede conclusao de PAGE para aquela regra.")
finally:
    db.close()
PY
