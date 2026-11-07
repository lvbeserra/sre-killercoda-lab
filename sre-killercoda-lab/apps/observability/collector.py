#!/usr/bin/env python3
"""Coletor sintético leve para Kubernetes KillerCoda (somente LAB).
Consulta Apache HTTP e métricas do Worker em intervalo fixo e persiste
histórico de disponibilidade e latência em SQLite/PVC (não no Git).
Sem bibliotecas externas, sem informações de pagamento ou segredos.
"""
import argparse
import json
import math
import os
import sqlite3
import time
import urllib.request
from datetime import datetime, timezone

DB_PATH = os.getenv("SRE_OBSERVER_DB", "/data/observations.sqlite3")
INTERVAL = max(10, int(os.getenv("SRE_OBSERVER_INTERVAL_SECONDS", "30")))
TARGETS = {
    "apache_http": (
        "http://apache.sre-middleware-lab.svc.cluster.local/",
        b"SRE Middleware Lab",
    ),
    "notification_metrics": (
        "http://notification-worker-metrics.sre-middleware-lab.svc.cluster.local:9100/metrics",
        b"sre_notification_processed_total",
    ),
}


def log(**fields):
    print(json.dumps({"ts": int(time.time()), **fields}, ensure_ascii=False), flush=True)


def open_db():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=15)
    db.execute("PRAGMA busy_timeout=15000")
    db.execute(
        "CREATE TABLE IF NOT EXISTS samples ("
        " ts INTEGER NOT NULL, service TEXT NOT NULL, "
        " success INTEGER NOT NULL, latency_ms REAL, error TEXT)"
    )
    db.execute("CREATE INDEX IF NOT EXISTS idx_samples_service_time ON samples(service, ts)")
    db.commit()
    return db


def probe(name, url, expected):
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(url, timeout=4) as response:
            body = response.read(64 * 1024)
            if response.status != 200 or expected not in body:
                raise ValueError(f"HTTP {response.status} ou corpo inesperado")
        elapsed = (time.perf_counter() - started) * 1000
        return 1, round(elapsed, 2), None
    except Exception as exc:
        return 0, None, str(exc)[:120]


def collect(db):
    when = int(time.time())
    for name, (url, expected) in TARGETS.items():
        ok, latency, error = probe(name, url, expected)
        db.execute(
            "INSERT INTO samples (ts,service,success,latency_ms,error) VALUES (?,?,?,?,?)",
            (when, name, ok, latency, error),
        )
        log(event="SYNTHETIC_SAMPLE", service=name, success=ok, latency_ms=latency, error=error)
    db.commit()


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    return round(ordered[math.ceil(fraction * len(ordered)) - 1], 2)


def report(db, window_minutes):
    now = int(time.time())
    since = now - window_minutes * 60
    output = {"window_minutes": window_minutes, "observation_time_utc": datetime.fromtimestamp(now, timezone.utc).isoformat(), "services": {}}
    for name in TARGETS:
        rows = db.execute(
            "SELECT ts, success, latency_ms FROM samples WHERE service=? AND ts>=? AND ts<=? ORDER BY ts",
            (name, since, now),
        ).fetchall()
        total = len(rows)
        successes = sum(x[1] for x in rows)
        failures = total - successes
        good_latency = [x[2] for x in rows if x[1] and x[2] is not None]
        observed = (100 * successes / total) if total else None
        burn = ((failures / total) / 0.001) if total else None
        coverage = rows[-1][0] - rows[0][0] if len(rows) >= 2 else 0
        output["services"][name] = {
            "total": total,
            "success": successes,
            "failures": failures,
            "availability_sample_percent": round(observed, 3) if observed is not None else None,
            "p50_success_ms": percentile(good_latency, 0.5),
            "p95_success_ms": percentile(good_latency, 0.95),
            "burn_rate_sample": round(burn, 2) if burn is not None else None,
            "coverage_seconds": coverage,
            "history_sufficient_for_window": coverage >= window_minutes * 60 * 0.9,
        }
    print(json.dumps({"kind": "SRE_HISTORICAL_SNAPSHOT", **output}, indent=2))
    print("AVISO: probes INTERNOS ao cluster não detectam queda total do cluster. Dados efêmeros da VM e não são SLO de clientes reais.")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["run", "once", "report"])
    parser.add_argument("--window-minutes", type=int, default=5)
    args = parser.parse_args()
    if args.window_minutes <= 0:
        parser.error("--window-minutes deve ser maior que zero")
    db = open_db()
    try:
        if args.command == "once":
            collect(db)
        elif args.command == "report":
            report(db, args.window_minutes)
        else:
            log(event="SRE_OBSERVER_READY", interval_seconds=INTERVAL, database=DB_PATH)
            while True:
                cycle_start = time.monotonic()
                collect(db)
                time.sleep(max(1, INTERVAL - (time.monotonic() - cycle_start)))
    finally:
        db.close()


if __name__ == "__main__":
    main()
