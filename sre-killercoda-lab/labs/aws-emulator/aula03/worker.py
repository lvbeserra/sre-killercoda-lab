"""Aulas 03/06: worker SQS -> S3 -> PDF -> PostgreSQL -> DynamoDB.

Uso exclusivo com AWS Emulator 127.0.0.1; sem acesso a AWS real.
"""
import argparse
import io
import json
import logging
import os
import time
import uuid

import boto3
import psycopg
from botocore.exceptions import BotoCoreError, ClientError
from pypdf import PdfReader

ENDPOINT = "https://127.0.0.1:9297"
QUEUE_NAME = "curriculos-processar"
DYNAMO_TABLE = "sre-lab-jobs"
DB_DSN = "dbname=sre_curriculos user=root host=/var/run/postgresql"
MAX_PDF_BYTES = 5 * 1024 * 1024

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s worker=%(name)s %(message)s",
)
logger = logging.getLogger("worker")


def emulator_clients():
    if os.environ.get("AWS_ENDPOINT_URL") != ENDPOINT:
        raise RuntimeError("Endpoint diferente do AWS Emulator; abortando")
    ca = os.environ.get("AWS_CA_BUNDLE")
    if not ca or not os.path.isfile(ca):
        raise RuntimeError("CA do AWS Emulator ausente; source env.sh")
    session = boto3.Session(region_name="us-east-1")
    common = {"endpoint_url": ENDPOINT, "verify": ca}
    if session.client("sts", **common).get_caller_identity()["Account"] != "000000000000":
        raise RuntimeError("Conta real detectada; processamento bloqueado")
    return session.client("s3", **common), session.client("sqs", **common), session.client("dynamodb", **common)


def extract_pdf_text(pdf_bytes):
    if len(pdf_bytes) > MAX_PDF_BYTES or not pdf_bytes.startswith(b"%PDF-"):
        raise ValueError("PDF invalido ou excede 5 MiB")
    pdf = PdfReader(io.BytesIO(pdf_bytes))
    if len(pdf.pages) > 20:
        raise ValueError("Laboratorio limitado a 20 paginas")
    return "\n".join((page.extract_text() or "") for page in pdf.pages)


def process_message(worker_id, s3, sqs, dynamodb, queue_url, message):
    receipt = message["ReceiptHandle"]
    try:
        job = json.loads(message["Body"])
        job_id = str(uuid.UUID(job["job_id"]))
        bucket = job["bucket"]
        key = job["key"]
        if bucket != "curriculos-lab" or not key.startswith("uploads/"):
            raise ValueError("Bucket/key nao pertence ao laboratorio")
        if key != "uploads/" + job_id + ".pdf":
            raise ValueError("job_id nao corresponde ao nome do objeto")
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("Mensagem fora do formato da Aula 03: %s. Mantida na fila.", type(exc).__name__)
        return False

    try:
        with psycopg.connect(DB_DSN) as conn:
            with conn.transaction():
                with conn.cursor() as cur:
                    # Lock transacional no job_id: apenas um worker processa esse ID por vez.
                    cur.execute("SELECT pg_advisory_xact_lock(hashtext(%s))", (job_id,))
                    cur.execute(
                        "SELECT 1 FROM processed_jobs WHERE job_id = %s::uuid",
                        (job_id,),
                    )
                    if cur.fetchone() is None:
                        response = s3.get_object(Bucket=bucket, Key=key)
                        pdf_bytes = response["Body"].read(MAX_PDF_BYTES + 1)
                        pdf_text = extract_pdf_text(pdf_bytes)
                        cur.execute(
                            """
                            INSERT INTO processed_jobs
                              (job_id, bucket, object_key, worker_id, extracted_text)
                            VALUES (%s::uuid, %s, %s, %s, %s)
                            """,
                            (job_id, bucket, key, worker_id, pdf_text),
                        )
                        logger.info("PROCESSADO job_id=%s paginas/texto extraidos", job_id)
                    else:
                        logger.info("DUPLICADO job_id=%s ja gravado; ignorando", job_id)
            # A transacao confirmou antes do ACK da fila.
        # PostgreSQL confirma primeiro; DynamoDB e gravado antes do ACK SQS.
        # Em falha do DynamoDB, mensagem volta e PG nao processa duas vezes.
        try:
            dynamodb.put_item(
                TableName=DYNAMO_TABLE,
                Item={
                    "job_id": {"S": job_id},
                    "status": {"S": "PROCESSADO"},
                    "worker": {"S": str(worker_id)},
                    "arquivo": {"S": key},
                },
                ConditionExpression="attribute_not_exists(job_id)",
            )
            logger.info("DYNAMODB PROCESSADO job_id=%s", job_id)
        except ClientError as exc:
            if exc.response.get("Error", {}).get("Code") != "ConditionalCheckFailedException":
                raise
            logger.info("DYNAMODB DUPLICADO job_id=%s; registro preservado", job_id)
        sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt)
        logger.info("ACK SQS job_id=%s", job_id)
        return True
    except (BotoCoreError, ClientError, psycopg.Error, ValueError, OSError, Exception):
        # Nao apaga a mensagem: SQS a disponibiliza novamente apos visibility timeout.
        logger.exception("ERRO job_id=%s; sem ACK, aguardando redelivery", job_id)
        return False


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--worker-id", required=True)
    args = parser.parse_args()

    s3, sqs, dynamodb = emulator_clients()
    queue_url = sqs.get_queue_url(QueueName=QUEUE_NAME)["QueueUrl"]
    logger.info("Worker iniciado id=%s fila=%s", args.worker_id, QUEUE_NAME)
    while True:
        try:
            batch = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=3,
                VisibilityTimeout=60,
            ).get("Messages", [])
            for message in batch:
                process_message(args.worker_id, s3, sqs, dynamodb, queue_url, message)
        except KeyboardInterrupt:
            logger.info("Worker encerrado pelo usuario")
            return
        except Exception:
            logger.exception("Falha de polling; nova tentativa em 3s")
            time.sleep(3)


if __name__ == "__main__":
    main()
