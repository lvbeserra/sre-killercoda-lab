"""Dados somente leitura para painel didatico AWS Emulator.

Nao usa AWS real. O caller deve passar api.clients, que valida endpoint e Account.
"""
from datetime import datetime, timezone
from pathlib import Path

import psycopg

DB_DSN = "dbname=sre_curriculos user=root host=/var/run/postgresql"


def worker_state(number):
    pid_path = Path("/tmp/aws-emulator-worker-" + str(number) + ".pid")
    log_path = Path("/tmp/aws-emulator-worker-" + str(number) + ".log")
    pid = None
    active = False
    if pid_path.is_file():
        try:
            pid = int(pid_path.read_text(encoding="utf-8").strip())
            proc = Path("/proc") / str(pid) / "cmdline"
            if proc.is_file():
                command = proc.read_bytes().replace(b"\x00", b" ").decode("utf-8", "replace")
                active = "worker.py" in command and "--worker-id " + str(number) in command
        except (ValueError, OSError):
            pass
    recent_logs = []
    if log_path.is_file():
        try:
            # Laboratorio pequeno: cap de 64 KiB evita ler logs arbitrariamente grandes.
            with log_path.open("rb") as handle:
                handle.seek(0, 2)
                length = handle.tell()
                handle.seek(max(0, length - 65536))
                recent_logs = handle.read().decode("utf-8", "replace").splitlines()[-8:]
        except OSError:
            recent_logs = ["Log indisponivel"]
    return {
        "name": "Worker " + str(number),
        "pid": pid,
        "active": active,
        "logs": recent_logs,
    }


def snapshot(clients_factory):
    s3, sqs = clients_factory()  # Usa SDK e credenciais validas do emulador.
    result = {
        "mode": "AWS_EMULATOR",
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "account": "000000000000",
        "buckets": [],
        "queues": [],
        "jobs": [],
        "workers": [worker_state(1), worker_state(2)],
        "warnings": [],
    }

    try:
        buckets = s3.list_buckets().get("Buckets", [])[:10]
        for entry in buckets:
            name = entry["Name"]
            objects = []
            try:
                response = s3.list_objects_v2(Bucket=name, MaxKeys=25)
                for obj in response.get("Contents", []):
                    objects.append({"key": obj.get("Key", ""), "size": obj.get("Size", 0)})
            except Exception:
                result["warnings"].append("Nao foi possivel listar objetos do bucket " + name)
            result["buckets"].append({"name": name, "objects": objects})
    except Exception:
        result["warnings"].append("Erro ao consultar buckets no emulador.")

    try:
        queue_urls = sqs.list_queues().get("QueueUrls", [])[:10]
        for queue_url in queue_urls:
            queue_name = queue_url.rsplit("/", 1)[-1]
            attrs = {}
            try:
                attrs = sqs.get_queue_attributes(
                    QueueUrl=queue_url,
                    AttributeNames=["ApproximateNumberOfMessages", "ApproximateNumberOfMessagesNotVisible"],
                ).get("Attributes", {})
            except Exception:
                result["warnings"].append("Contadores indisponiveis para fila " + queue_name)
            result["queues"].append({
                "name": queue_name,
                "visible": attrs.get("ApproximateNumberOfMessages", "?"),
                "inflight": attrs.get("ApproximateNumberOfMessagesNotVisible", "?"),
            })
    except Exception:
        result["warnings"].append("Erro ao consultar filas no emulador.")

    try:
        with psycopg.connect(DB_DSN) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT job_id::text, worker_id, object_key, "
                    "left(extracted_text, 120), processed_at::text "
                    "FROM processed_jobs ORDER BY processed_at DESC LIMIT 20"
                )
                for job_id, worker_id, key, snippet, when in cur.fetchall():
                    result["jobs"].append({
                        "job_id": job_id,
                        "worker_id": worker_id,
                        "s3_key": key,
                        "snippet": snippet,
                        "processed_at": when,
                    })
    except Exception:
        result["warnings"].append("PostgreSQL indisponivel ou tabela ainda nao criada.")

    return result
