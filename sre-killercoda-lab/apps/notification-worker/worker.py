#!/usr/bin/env python3
"""Consumidor RabbitMQ para NOTIFICACOES de pagamentos FICTICIOS.

Manual ACK somente depois de simular o processamento. Nao envia mensagens reais.
Sem persistencia de deduplicacao: pode haver entregas duplicadas em falhas.
"""
import json
import os
import signal
import time

import pika

QUEUE = os.getenv("RABBIT_QUEUE", "notificacoes-pagamentos")
HOST = os.getenv("RABBIT_HOST", "rabbitmq")
USERNAME = os.getenv("RABBIT_USER", "labuser")
PASSWORD = os.environ["RABBIT_PASSWORD"]
READY_FILE = "/tmp/notification-worker-ready"
running = True


def log(**fields):
    print(json.dumps({"ts": int(time.time()), **fields}, ensure_ascii=False), flush=True)


def stop(_signum, _frame):
    global running
    running = False
    log(event="SIGTERM", status="shutdown_requested")


def main():
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
            channel.queue_declare(queue=QUEUE, durable=True)
            channel.basic_qos(prefetch_count=1)
            open(READY_FILE, "w").close()
            log(event="WORKER_READY", queue=QUEUE)
            for method, _properties, body in channel.consume(
                queue=QUEUE, inactivity_timeout=1, auto_ack=False
            ):
                if not running:
                    break
                if method is None:
                    continue
                try:
                    payload = json.loads(body.decode("utf-8"))
                    if not isinstance(payload, dict) or not payload.get("pagamento_id"):
                        raise ValueError("mensagem sem pagamento_id")
                except (ValueError, UnicodeError) as exc:
                    log(event="INVALID_NOTIFICATION", error=str(exc))
                    # Simples demonstracao: em producao usar DLQ e trilha de auditoria.
                    channel.basic_reject(delivery_tag=method.delivery_tag, requeue=False)
                    continue
                payment_id = payload["pagamento_id"]
                # Processamento simulado e sem efeito externo:
                log(event="NOTIFICATION_PROCESSED", pagamento_id=payment_id)
                channel.basic_ack(delivery_tag=method.delivery_tag)
                log(event="ACK", pagamento_id=payment_id, queue=QUEUE)
            if channel.is_open:
                channel.cancel()
        except Exception as exc:
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
    log(event="WORKER_EXIT")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    main()
