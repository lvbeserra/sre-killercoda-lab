#!/usr/bin/env python3
"""Kafka -> RabbitMQ bridge para APENAS pagamentos fictícios no lab SRE.

Sem dados reais; entrega pelo menos uma vez (pode duplicar após falha).
Um commit do offset só ocorre após confirmação de publicação no RabbitMQ.
"""
import json
import os
import signal
import sys
import time

from confluent_kafka import Consumer
import pika

TOPIC = os.getenv("KAFKA_TOPIC", "pagamentos-simulados")
BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "kafka:9092")
RABBIT_HOST = os.getenv("RABBIT_HOST", "rabbitmq")
RABBIT_QUEUE = os.getenv("RABBIT_QUEUE", "notificacoes-pagamentos")
RABBIT_USER = os.getenv("RABBIT_USER", "labuser")
RABBIT_PASSWORD = os.environ["RABBIT_PASSWORD"]
RUNNING = True


def log(**fields):
    print(json.dumps({"ts": int(time.time()), **fields}, ensure_ascii=False), flush=True)


def stop(_signum, _frame):
    global RUNNING
    RUNNING = False
    log(event="SIGTERM", status="shutdown_requested")


def send_to_rabbit(event: dict):
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(
            host=RABBIT_HOST,
            port=5672,
            virtual_host="/",
            credentials=pika.PlainCredentials(RABBIT_USER, RABBIT_PASSWORD),
            heartbeat=30,
            socket_timeout=10,
            blocked_connection_timeout=10,
            connection_attempts=2,
            retry_delay=2,
        )
    )
    try:
        channel = connection.channel()
        channel.queue_declare(queue=RABBIT_QUEUE, durable=True)
        channel.confirm_delivery()
        notification = {
            "tipo": "NOTIFICACAO_PAGAMENTO_SIMULADO",
            "pagamento_id": event["pagamento_id"],
            "status": event.get("status", "SIMULADO"),
            "origem": "kafka-to-rabbitmq",
        }
        channel.basic_publish(
            exchange="",
            routing_key=RABBIT_QUEUE,
            body=json.dumps(notification, ensure_ascii=False).encode(),
            properties=pika.BasicProperties(
                content_type="application/json",
                delivery_mode=2,  # persistente *se* o armazenamento do RabbitMQ persistir
            ),
            mandatory=True,
        )
        return notification
    finally:
        if connection.is_open:
            connection.close()


def main():
    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP,
            "group.id": "sre-pagamentos-bridge-v1",
            "enable.auto.commit": False,
            "auto.offset.reset": "earliest",
            "client.id": "sre-payment-bridge",
            "session.timeout.ms": 12000,
        }
    )
    consumer.subscribe([TOPIC])
    log(event="BRIDGE_START", topic=TOPIC, queue=RABBIT_QUEUE)
    try:
        while RUNNING:
            msg = consumer.poll(timeout=1.0)
            if msg is None:
                continue
            if msg.error():
                log(event="KAFKA_ERROR", error=str(msg.error()))
                continue
            try:
                event = json.loads(msg.value())
                if not isinstance(event, dict) or not event.get("pagamento_id"):
                    # Próxima aula: DLQ e poison messages.
                    raise ValueError("JSON sem pagamento_id")
            except (ValueError, TypeError, UnicodeDecodeError) as exc:
                log(event="INVALID_EVENT", partition=msg.partition(), offset=msg.offset(), error=str(exc))
                # Avança para não travar o consumer de laboratório com eventos malformados.
                consumer.commit(message=msg, asynchronous=False)
                continue

            while RUNNING:
                try:
                    notification = send_to_rabbit(event)
                    consumer.commit(message=msg, asynchronous=False)
                    log(
                        event="FORWARDED",
                        pagamento_id=notification["pagamento_id"],
                        kafka_partition=msg.partition(),
                        kafka_offset=msg.offset(),
                        rabbit_queue=RABBIT_QUEUE,
                    )
                    break
                except Exception as exc:
                    log(event="PUBLISH_RETRY", pagamento_id=event["pagamento_id"], error=str(exc))
                    time.sleep(3)
    finally:
        consumer.close()
        log(event="BRIDGE_EXIT")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        main()
    except Exception as exc:
        log(event="FATAL", error=str(exc))
        sys.exit(1)
