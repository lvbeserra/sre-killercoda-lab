"""Aula 02: FastAPI -> S3 emulado -> SQS emulado. Nunca usa AWS real."""
import json
import logging
import os
from uuid import uuid4

import boto3
from botocore.exceptions import BotoCoreError, ClientError
from fastapi import FastAPI, File, HTTPException, UploadFile

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("aula02")
app = FastAPI(title="SRE Lab - AWS Emulator", version="0.2.0")

ENDPOINT = "https://127.0.0.1:9297"
BUCKET = "curriculos-lab"
QUEUE = "curriculos-processar"
MAX_BYTES = 5 * 1024 * 1024


def clients():
    """Bloqueia qualquer uso acidental de conta AWS verdadeira."""
    if os.environ.get("AWS_ENDPOINT_URL") != ENDPOINT:
        raise RuntimeError("AWS_ENDPOINT_URL deve apontar ao emulator local")
    ca_file = os.environ.get("AWS_CA_BUNDLE")
    if not ca_file or not os.path.isfile(ca_file):
        raise RuntimeError("CA do emulator ausente; execute source env.sh")
    session = boto3.Session(region_name="us-east-1")
    common = {"endpoint_url": ENDPOINT, "verify": ca_file}
    account = session.client("sts", **common).get_caller_identity()["Account"]
    if account != "000000000000":
        raise RuntimeError("Conta nao emulada: operacao bloqueada")
    return session.client("s3", **common), session.client("sqs", **common)


@app.get("/health")
def health():
    return {"status": "ok", "servico": "aula02-api"}


@app.get("/ready")
def ready():
    try:
        clients()
    except (RuntimeError, BotoCoreError, ClientError) as exc:
        logger.warning("Emulador indisponivel: %s", type(exc).__name__)
        raise HTTPException(status_code=503, detail="AWS Emulator indisponivel") from exc
    return {"status": "ready", "aws_account": "000000000000"}


@app.post("/resumes", status_code=202)
async def upload_resume(file: UploadFile = File(...)):
    name = file.filename or ""
    if not name.lower().endswith(".pdf"):
        raise HTTPException(status_code=415, detail="Envie um arquivo .pdf")

    data = await file.read(MAX_BYTES + 1)
    await file.close()
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="Limite de 5 MiB excedido")
    if not data.startswith(b"%PDF-"):
        raise HTTPException(status_code=415, detail="Conteudo nao parece um PDF")

    job_id = str(uuid4())
    key = "uploads/" + job_id + ".pdf"
    try:
        s3, sqs = clients()
        queue_url = sqs.get_queue_url(QueueName=QUEUE)["QueueUrl"]
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=data,
            ContentType="application/pdf",
        )
        message = {
            "job_id": job_id,
            "bucket": BUCKET,
            "key": key,
            "status": "PENDENTE",
        }
        sent = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message),
        )
    except (RuntimeError, ClientError, BotoCoreError, OSError) as exc:
        logger.exception("Falha de integracao S3/SQS; verifique logs e estado do objeto")
        raise HTTPException(status_code=503, detail="Falha ao publicar PDF no laboratorio") from exc

    logger.info("job_id=%s s3_key=%s sqs_message_id=%s", job_id, key, sent["MessageId"])
    return {
        "status": "PENDENTE",
        "job_id": job_id,
        "bucket": BUCKET,
        "s3_key": key,
        "sqs_message_id": sent["MessageId"],
    }
