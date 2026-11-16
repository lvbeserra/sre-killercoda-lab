"""Aula 04: teste isolado de redrive SQS em AWS Emulator (nunca AWS real)."""
import json
import os
import sys
import time
import uuid

import boto3

ENDPOINT = "https://127.0.0.1:9297"
ACCOUNT = "000000000000"
SOURCE = "curriculos-aula04"
DLQ = "curriculos-aula04-dlq"


def main():
    if os.getenv("AWS_ENDPOINT_URL") != ENDPOINT:
        sys.exit("ABORTADO: execute source ../env.sh antes do teste.")
    ca = os.getenv("AWS_CA_BUNDLE")
    if not ca or not os.path.isfile(ca):
        sys.exit("ABORTADO: certificado CA do emulador ausente.")
    session = boto3.Session(region_name="us-east-1")
    opts = {"endpoint_url": ENDPOINT, "verify": ca}
    account = session.client("sts", **opts).get_caller_identity()["Account"]
    if account != ACCOUNT:
        sys.exit("ABORTADO: conta diferente da conta ficticia 000000000000.")
    sqs = session.client("sqs", **opts)
    source_url = sqs.create_queue(QueueName=SOURCE)["QueueUrl"]
    dlq_url = sqs.create_queue(QueueName=DLQ)["QueueUrl"]
    dlq_arn = sqs.get_queue_attributes(
        QueueUrl=dlq_url, AttributeNames=["QueueArn"]
    )["Attributes"]["QueueArn"]
    policy = json.dumps({"deadLetterTargetArn": dlq_arn, "maxReceiveCount": "3"})
    sqs.set_queue_attributes(
        QueueUrl=source_url,
        Attributes={"RedrivePolicy": policy, "VisibilityTimeout": "2"},
    )
    actual = sqs.get_queue_attributes(
        QueueUrl=source_url, AttributeNames=["RedrivePolicy"]
    )["Attributes"].get("RedrivePolicy")
    if not actual or json.loads(actual).get("deadLetterTargetArn") != dlq_arn:
        sys.exit("ERRO: emulador nao confirmou a RedrivePolicy; teste abortado.")
    print("RedrivePolicy confirmada: 3 recebimentos ->", DLQ, flush=True)

    # Filas dedicadas ao teste, sem tocar nas mensagens das aulas anteriores.
    # Se o mesmo laboratorio for reexecutado, mensagens antigas podem existir.
    tag = "falha-aula04-" + str(uuid.uuid4())
    sqs.send_message(QueueUrl=source_url, MessageBody=json.dumps({
        "test_id": tag, "simular_falha": True
    }))
    print("Enviado:", tag, flush=True)

    receives = 0
    found_dlq = False
    deadline = time.monotonic() + 65
    while time.monotonic() < deadline:
        batch = sqs.receive_message(
            QueueUrl=source_url, MaxNumberOfMessages=10,
            WaitTimeSeconds=1, VisibilityTimeout=2,
            AttributeNames=["ApproximateReceiveCount"],
        ).get("Messages", [])
        for message in batch:
            body = json.loads(message["Body"])
            if body.get("test_id") == tag:
                receives += 1
                print("FALHA INTENCIONAL: tentativa",
                      message.get("Attributes", {}).get("ApproximateReceiveCount", "?"),
                      "- mensagem NAO confirmada (sem delete_message)", flush=True)
            else:
                # Nao excluir nem alterar mensagens que nao pertencem ao teste.
                print("Mensagem preexistente na fila de teste; preservada.", flush=True)
        dlq_batch = sqs.receive_message(
            QueueUrl=dlq_url, MaxNumberOfMessages=10,
            WaitTimeSeconds=1, VisibilityTimeout=2,
        ).get("Messages", [])
        for message in dlq_batch:
            body = json.loads(message["Body"])
            if body.get("test_id") == tag:
                found_dlq = True
                print("SUCESSO: mensagem da falha localizada na DLQ:", tag, flush=True)
                break
        if found_dlq:
            break
        time.sleep(1)
    if not found_dlq:
        sys.exit("NAO VALIDADO: mensagem nao apareceu na DLQ em 65 s. "
                 "Verifique suporte RedrivePolicy no AWS Emulator e os contadores SQS.")
    print("Aula 04 aprovada. Recebimentos detectados:", receives,
          "| DLQ:", DLQ, flush=True)


if __name__ == "__main__":
    main()
