#!/usr/bin/env bash
# Teste de API S3 e SQS somente contra AWS Emulator local.
set -euo pipefail
if [ "${AWS_ENDPOINT_URL:-}" != 'https://127.0.0.1:9297' ]; then
  echo 'ABORTADO: rode source env.sh e confirme o endpoint local.' >&2
  exit 1
fi
if ! command -v aws >/dev/null 2>&1; then
  echo 'AWS CLI nao instalado. Leia o README para instalar AWS CLI v2.' >&2
  exit 1
fi
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "$account" != '000000000000' ]; then
  echo "ABORTADO: Account=$account nao e a conta emulada." >&2
  exit 1
fi
echo 'Conta AWS Emulator confirmada: 000000000000'
bucket=curriculos-lab
if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
  echo "Bucket existente: $bucket"
else
  aws s3 mb "s3://$bucket"
fi
printf 'Laboratorio ficticio AWS Emulator\n' > /tmp/aws-emulator-teste.txt
aws s3 cp /tmp/aws-emulator-teste.txt "s3://$bucket/teste.txt"
aws s3 ls "s3://$bucket/"
# Nao executar CreateQueue numa fila preexistente: pode ter RedrivePolicy.
# AWS Emulator rejeita CreateQueue com atributos diferentes (QueueAlreadyExists).
fresh_queue=0
if queue_url="$(aws sqs get-queue-url --queue-name curriculos-processar --query QueueUrl --output text 2>/dev/null)"; then
  echo 'Fila existente: curriculos-processar (atributos preservados)'
else
  queue_url="$(aws sqs create-queue --queue-name curriculos-processar --query QueueUrl --output text)"
  echo 'Fila criada: curriculos-processar'
  fresh_queue=1
fi
if aws sqs get-queue-url --queue-name curriculos-dlq >/dev/null 2>&1; then
  echo 'Fila existente: curriculos-dlq (mensagens preservadas)'
else
  aws sqs create-queue --queue-name curriculos-dlq
fi
if [ "$fresh_queue" = 1 ]; then
  # Mensagem didatica identificavel; consumo e ACK apos teste evitam poison message
  # antiga gerando KeyError infinito nos workers da Aula 03.
  aws sqs send-message --queue-url "$queue_url" --message-body '{"arquivo":"teste.txt","status":"PENDENTE"}'
  receipt="$(aws sqs receive-message --queue-url "$queue_url" --query 'Messages[0].ReceiptHandle' --output text)"
  if [ -n "$receipt" ] && [ "$receipt" != None ]; then
    aws sqs delete-message --queue-url "$queue_url" --receipt-handle "$receipt"
    echo 'Mensagem de teste enviada, recebida e confirmada (ACK SQS).'
  else
    echo 'Aviso: mensagem de teste nao recebida neste polling; verifique a fila antes de iniciar workers.' >&2
  fi
else
  echo 'Teste de mensagem ignorado: fila preexistente, sem criar novo job invalido.'
fi
echo 'Aula 01: S3 e SQS preparados.'
