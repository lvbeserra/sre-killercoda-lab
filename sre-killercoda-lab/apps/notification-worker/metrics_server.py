#!/usr/bin/env python3
"""Exposição Prometheus leve para o notification-worker fictício.

HTTP interno /metrics na porta 9100, sem bibliotecas adicionais.
Contadores são relativos ao processo: reiniciam quando o Pod reinicia.
Nenhum pagamento_id ou credencial aparece como label.
"""
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

COUNTERS = {
    "processed": 0,
    "duplicate_skipped": 0,
    "invalid": 0,
    "ack": 0,
    "db_error": 0,
    "reconnect": 0,
}
LOCK = threading.Lock()
START = int(time.time())


def increment(name):
    with LOCK:
        COUNTERS[name] += 1


def exposition():
    with LOCK:
        snapshot = COUNTERS.copy()
    descriptions = {
        "processed": "Notificacoes ficticias processadas pela primeira vez",
        "duplicate_skipped": "Notificacoes duplicadas ignoradas",
        "invalid": "Notificacoes invalidas rejeitadas para DLQ",
        "ack": "Mensagens RabbitMQ confirmadas com ACK",
        "db_error": "Falhas de escrita na base de deduplicacao",
        "reconnect": "Reconexoes RabbitMQ solicitadas pelo worker",
    }
    lines = []
    for key, value in snapshot.items():
        name = "sre_notification_" + key + "_total"
        lines.extend([
            "# HELP " + name + " " + descriptions[key],
            "# TYPE " + name + " counter",
            name + " " + str(value),
        ])
    lines.extend([
        "# HELP sre_notification_start_time_seconds Inicio deste processo Unix",
        "# TYPE sre_notification_start_time_seconds gauge",
        "sre_notification_start_time_seconds " + str(START),
    ])
    return ("\n".join(lines) + "\n").encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            data = exposition()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif self.path == "/health":
            data = b"ok\n"
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        else:
            self.send_error(404, "Not Found")

    def log_message(self, _fmt, *_args):
        return


def start_metrics_server(port=9100):
    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True, name="prometheus-metrics")
    thread.start()
    return server
