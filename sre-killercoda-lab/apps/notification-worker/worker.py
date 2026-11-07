#!/usr/bin/env python3
"""Worker de notificações de PAGAMENTOS FICTÍCIOS: ACK manual, dedup SQLite, DLQ.

Contrato didático:
- Registra pagamento_id em SQLite antes do ACK; duplicatas são ACK sem reprocessar.
- Mensagens JSON inválidas ou sem ID são rejeitadas para a DLQ (via policy RabbitMQ).
- Não envia e-mails, não movimenta dinheiro e não executa outros efeitos externos.
- SQLite exige uma única réplica e PVC; não fornece exactly-once em sistemas externos.
"""
import json
import os
import signal
import sqlite3
import time

import pika
from metrics_server import increment, start_metrics_server

QUEUE = os.getenv("RABBIT_QUEUE", "notificacoes-pagamentos")
DLQ = os.getenv("RABBIT_DLQ", "notificacoes-pagamentos-dlq")
HOST = os.getenv("RABBIT_HOST", "rabbitmq")
USERNAME = os.getenv("RABBIT_USER", "labuser")
PASSWORD = os.environ["RABBIT_PASSWORD"]
DB_PATH = os.getenv("DEDUP_DB_PATH", "/data/processed.sqlite3")
READY_FILE = "/tmp/notification-worker-ready"
running = True


def log(**fields):
    print(json.dumps({"ts": int(time.time()), **fields}, ensure_ascii=False), flush=True)


def stop(_signum, _frame):
    global running
    running = False
    log(event="SIGTERM", status="shutdown_requested")


def open_database():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    db = sqlite3.connect(DB_PATH, timeout=20)
    db.execute("PRAGMA busy_timeout = 20000")
    db.execute(
        "CREATE TABLE IF NOT EXISTS processed_payments ("
        " pagamento_id TEXT PRIMARY KEY NOT NULL,"
        " processed_at INTEGER NOT NULL)"
    )
    db.commit()
    return db


def handle_delivery(channel, method, properties, body, database):
    try:
        payload = json.loads(body.decode("utf-8"))
        if not isinstance(payload, dict):
            raise ValueError("payload não é objeto JSON")
        payment_id = payload.get("pagamento_id")
        if not isinstance(payment_id, str) or not payment_id.strip():
            raise ValueError("pagamento_id deve ser string não vazia")
    except (ValueError, UnicodeError) as exc:
        log(
            event="INVALID_NOTIFICATION",
            message_id=getattr(properties, "message_id", None),
            error=str(exc),
            action="REJECT_TO_DLQ",
        )
        channel.basic_reject(delivery_tag=method.delivery_tag, requeue=False)
        increment("invalid")
        return

    # Como NÃO há efeito externo, registrar na tabela é o "processamento"
    # desta aula. Com efeitos externos, precisamos de outbox/idempotência no destino.
    try:
        cursor = database.execute(
            "INSERT OR IGNORE INTO processed_payments (pagamento_id, processed_at)"
            " VALUES (?, ?)",
            (payment_id, int(time.time())),
        )
        database.commit()
    except sqlite3.Error as exc:
        database.rollback()
        log(event="DB_ERROR", pagamento_id=payment_id, error=str(exc))
        increment("db_error")
        channel.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
        time.sleep(2)
        return

    if cursor.rowcount == 1:
        log(event="NOTIFICATION_PROCESSED", pagamento_id=payment_id)
        increment("processed")
    else:
        log(event="DUPLICATE_SKIPPED", pagamento_id=payment_id)
        increment("duplicate_skipped")
    channel.basic_ack(delivery_tag=method.delivery_tag)
    increment("ack")
    log(event="ACK", pagamento_id=payment_id, queue=QUEUE)


def main():
    database = open_database()
    start_metrics_server()
    log(event="METRICS_READY", endpoint=":9100/metrics")
    log(event="DB_READY", db_path=DB_PATH)
    try:
        while running:
            connection = None
            try:
                connection = pika.BlockingConnection(
                    pika.ConnectionParameters(
                        host=HOST,
                        port=5672,
                        credentials=pika.PlainCredentials(USERNAME, PASSWORD),
                        heartbeat=30,
                        socket_timeout=10,
                        blocked_connection_timeout=10,
                        connection_attempts=2,
                        retry_delay=2,
                    )
                )
                channel = connection.channel()
                channel.queue_declare(queue=DLQ, durable=True)
                channel.queue_declare(queue=QUEUE, durable=True)
                channel.basic_qos(prefetch_count=1)
                open(READY_FILE, "w").close()
                log(event="WORKER_READY", queue=QUEUE, dlq=DLQ)
                for method, properties, body in channel.consume(
                    queue=QUEUE, inactivity_timeout=1, auto_ack=False
                ):
                    if not running:
                        break
                    if method is None:
                        continue
                    handle_delivery(channel, method, properties, body, database)
                if channel.is_open:
                    channel.cancel()
            except Exception as exc:
                increment("reconnect")
                log(event="WORKER_RECONNECT", error=str(exc))
                if running:
                    time.sleep(3)
            finally:
                try:
                    os.unlink(READY_FILE)
                except FileNotFoundError:
                    pass
                if connection is not None and connection.is_open:
                    connection.close()
    finally:
        database.close()
    log(event="WORKER_EXIT")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    main()
