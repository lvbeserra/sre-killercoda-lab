#!/usr/bin/env bash
# Simula disputa por row lock do PostgreSQL somente no LAB e reverte transações.
# Não altera estado persistente e nunca deve ser usado fora do laboratório descartável.
set -euo pipefail
NS=sre-fullstack-lab
kubectl -n "$NS" rollout status deployment/incidents-api --timeout=60s
kubectl -n "$NS" exec -i deployment/incidents-api -- python - <<'PY'
import sys
import time
import threading
import psycopg

outcome = {"wait_seen": False, "timeout_seen": False}
blocker = None
monitor = None

def contender(row_id):
    conn = None
    try:
        conn = psycopg.connect(
            application_name="sre-lab-lock-waiter",
            connect_timeout=3,
            options="-c statement_timeout=7000",
        )
        conn.execute("SET LOCAL lock_timeout = '3500ms'")
        # A atualização, mesmo se concluir, será revertida no finally.
        conn.execute(
            "UPDATE incidents SET status = status WHERE id = %s",
            (row_id,),
        )
        outcome["unexpected_update_finished"] = True
    except psycopg.Error as exc:
        if getattr(exc, "sqlstate", None) == "55P03":
            outcome["timeout_seen"] = True
            print("EVENTO: SQLSTATE 55P03 — lock_timeout atingido (esperado).", flush=True)
        else:
            outcome["error"] = type(exc).__name__ + ": " + str(exc)
    finally:
        if conn is not None:
            conn.rollback()
            conn.close()

try:
    blocker = psycopg.connect(
        application_name="sre-lab-lock-holder",
        connect_timeout=3,
    )
    monitor = psycopg.connect(
        application_name="sre-lab-lock-monitor",
        connect_timeout=3,
        autocommit=True,
    )
    row = blocker.execute(
        "SELECT id FROM incidents ORDER BY id DESC LIMIT 1"
    ).fetchone()
    if row is None:
        print("ERRO: cadastre antes um incidente fictício no laboratório.")
        sys.exit(2)
    incident_id = row[0]
    blocker.execute(
        "SELECT id FROM incidents WHERE id = %s FOR UPDATE",
        (incident_id,),
    ).fetchone()
    print("TRANSAÇÃO A: row lock mantido no incidente fictício", incident_id, flush=True)

    worker = threading.Thread(target=contender, args=(incident_id,))
    worker.start()
    for _ in range(14):
        time.sleep(0.2)
        rows = monitor.execute(
            "SELECT pid, state, wait_event_type, wait_event, "
            "pg_blocking_pids(pid) "
            "FROM pg_stat_activity "
            "WHERE application_name = 'sre-lab-lock-waiter'"
        ).fetchall()
        for pid, state, wait_type, wait_event, blockers in rows:
            if wait_type == "Lock":
                outcome["wait_seen"] = True
                print(
                    "EVENTO: pid=%s state=%s wait_event_type=%s "
                    "wait_event=%s blocking_pids=%s" %
                    (pid, state, wait_type, wait_event, blockers),
                    flush=True,
                )
                break
        if outcome["wait_seen"]:
            break
    worker.join(timeout=6)
    if worker.is_alive():
        print("AVISO: consulta ainda ativa; liberando bloqueio.", flush=True)
    # O bloco finally garante ROLLBACK mesmo em caso de erro ou Ctrl+C.
finally:
    if blocker is not None:
        blocker.rollback()
        blocker.close()
        print("TRANSAÇÃO A: ROLLBACK e lock liberado.", flush=True)
    if monitor is not None:
        monitor.close()
    if "worker" in locals():
        worker.join(timeout=8)

print("=== RESULTADO DA SIMULAÇÃO ===")
print("Espera por lock observada:", outcome["wait_seen"])
print("Timeout de lock observado:", outcome["timeout_seen"])
print("Nenhuma atualização persistida: todas as transações foram revertidas.")
if outcome.get("error"):
    print("ERRO DA CONSULTA CONCORRENTE:", outcome["error"])
if not outcome["wait_seen"] or not outcome["timeout_seen"] or outcome.get("unexpected_update_finished"):
    print("ATENÇÃO: não foi possível confirmar a simulação completa.")
    sys.exit(1)
print("SUCESSO: bloqueio reproduzido, observado e encerrado com rollback.")
PY
