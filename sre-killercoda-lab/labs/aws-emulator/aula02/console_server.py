"""Servidor web separado, SOMENTE leitura, para Traffic/Ports do KillerCoda.

Porta 8001 pode ser acessada por quem obtiver o link de acesso do ambiente.
Nao serve dados pessoais nem endpoints de upload.
"""
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse

from api import clients
from console_backend import snapshot

app = FastAPI(
    title="SRE Lab AWS Emulator Console",
    docs_url=None,
    redoc_url=None,
    openapi_url=None,
)


@app.get("/console", include_in_schema=False)
def page():
    return FileResponse(Path(__file__).with_name("console.html"), media_type="text/html")


@app.get("/console/state", include_in_schema=False)
def state():
    return snapshot(clients)


@app.get("/health", include_in_schema=False)
def health():
    return {"status": "ok", "component": "read-only-console"}
