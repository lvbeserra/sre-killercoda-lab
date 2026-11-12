#!/usr/bin/env python3
"""API didática Python + PostgreSQL: quadro de incidentes SRE.

Endpoints: GET /healthz, GET /readyz, GET /api/health,
GET/POST /api/incidents, PATCH /api/incidents/<id>, GET /api/slow?ms=2000,
GET /metrics. Não usar em produção sem autenticação, TLS e controles adicionais.
"""
import json
import os
import re
import threading
import time
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import psycopg
from psycopg.rows import dict_row

DB_HOST = os.environ.get("PGHOST", "postgres")
DB_NAME = os.environ.get("PGDATABASE", "srelab")
DB_USER = os.environ.get("PGUSER", "labuser")
DB_PASSWORD = os.environ["PGPASSWORD"]
COUNTS = Counter()
LOCK = threading.Lock()


def connect_db():
    return psycopg.connect(
        host=DB_HOST,
        port=5432,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3,
        options="-c statement_timeout=4000",
    )


class API(BaseHTTPRequestHandler):
    server_version = "SreIncidentLab/1.0"

    def log_message(self, fmt, *args):
        print(json.dumps({"event": "http_access", "message": fmt % args}), flush=True)

    def send_json(self, code, obj, route):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
        with LOCK:
            COUNTS[(self.command, route, str(code))] += 1

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length < 2 or length > 4096:
            raise ValueError("JSON deve ter entre 2 e 4096 bytes")
        obj = json.loads(self.rfile.read(length).decode("utf-8"))
        if not isinstance(obj, dict):
            raise ValueError("Objeto JSON esperado")
        return obj

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/healthz":
            self.send_json(200, {"status": "alive"}, "/healthz")
            return
        if path in ("/readyz", "/api/health"):
            try:
                with connect_db() as conn:
                    result = conn.execute("SELECT 1").fetchone()[0]
                self.send_json(200, {"status": "ok", "database": "connected", "test": result}, path)
            except psycopg.Error as exc:
                print(json.dumps({"event": "db_error", "type": type(exc).__name__}), flush=True)
                self.send_json(503, {"status": "unavailable", "database": "disconnected"}, path)
            return
        if path == "/api/incidents":
            try:
                with connect_db() as conn:
                    with conn.cursor(row_factory=dict_row) as cur:
                        cur.execute(
                            "SELECT id, service, severity, status, description, "
                            "created_at::text AS created_at FROM incidents "
                            "ORDER BY id DESC LIMIT 50"
                        )
                        items = cur.fetchall()
                self.send_json(200, {"items": items}, path)
            except psycopg.Error as exc:
                print(json.dumps({"event": "db_error", "type": type(exc).__name__}), flush=True)
                self.send_json(503, {"error": "Banco de dados indisponível"}, path)
            return
        if path == "/api/slow":
            try:
                delay = int(parse_qs(urlparse(self.path).query).get("ms", ["2000"])[0])
                if delay < 0 or delay > 3000:
                    raise ValueError
            except (TypeError, ValueError):
                self.send_json(400, {"error": "ms deve estar entre 0 e 3000"}, path)
                return
            time.sleep(delay / 1000)
            self.send_json(200, {"simulated_delay_ms": delay}, path)
            return
        if path == "/metrics":
            with LOCK:
                snapshot = sorted(COUNTS.items())
            lines = [
                "# HELP sre_api_requests_total Requisicoes processadas por esta instancia de API",
                "# TYPE sre_api_requests_total counter",
            ]
            for (method, route, code), value in snapshot:
                lines.append(
                    'sre_api_requests_total{method="%s",route="%s",code="%s"} %d' %
                    (method, route, code, value)
                )
            body = ("\n".join(lines) + "\n").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        self.send_json(404, {"error": "Rota não encontrada"}, "404")

    def do_POST(self):
        if urlparse(self.path).path != "/api/incidents":
            self.send_json(404, {"error": "Rota não encontrada"}, "404")
            return
        try:
            data = self.read_json()
            service = str(data.get("service", "")).strip()
            severity = str(data.get("severity", "")).strip().upper()
            description = str(data.get("description", "")).strip()
            if not (1 <= len(service) <= 80 and
                    1 <= len(description) <= 500 and severity in ("P1", "P2", "P3")):
                raise ValueError("service(1-80), description(1-500), severity(P1/P2/P3) obrigatórios")
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            self.send_json(400, {"error": str(exc)}, "/api/incidents")
            return
        try:
            with connect_db() as conn:
                row = conn.execute(
                    "INSERT INTO incidents(service,severity,description) "
                    "VALUES (%s,%s,%s) RETURNING id",
                    (service, severity, description),
                ).fetchone()
            self.send_json(201, {"id": row[0], "status": "OPEN"}, "/api/incidents")
        except psycopg.Error as exc:
            print(json.dumps({"event": "db_error", "type": type(exc).__name__}), flush=True)
            self.send_json(503, {"error": "Banco de dados indisponível"}, "/api/incidents")

    def do_PATCH(self):
        match = re.fullmatch(r"/api/incidents/([0-9]+)", urlparse(self.path).path)
        if not match:
            self.send_json(404, {"error": "Rota não encontrada"}, "404")
            return
        try:
            body = self.read_json()
            status = str(body.get("status", "")).upper()
            if status not in ("OPEN", "INVESTIGATING", "RESOLVED"):
                raise ValueError("status inválido")
        except (ValueError, TypeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            self.send_json(400, {"error": str(exc)}, "/api/incidents/:id")
            return
        try:
            with connect_db() as conn:
                row = conn.execute(
                    "UPDATE incidents SET status=%s WHERE id=%s RETURNING id",
                    (status, int(match.group(1))),
                ).fetchone()
            if row is None:
                self.send_json(404, {"error": "Incidente não encontrado"}, "/api/incidents/:id")
            else:
                self.send_json(200, {"id": row[0], "status": status}, "/api/incidents/:id")
        except psycopg.Error as exc:
            print(json.dumps({"event": "db_error", "type": type(exc).__name__}), flush=True)
            self.send_json(503, {"error": "Banco de dados indisponível"}, "/api/incidents/:id")


if __name__ == "__main__":
    print(json.dumps({"event": "api_started", "port": 8000, "db_host": DB_HOST}), flush=True)
    ThreadingHTTPServer(("0.0.0.0", 8000), API).serve_forever()
