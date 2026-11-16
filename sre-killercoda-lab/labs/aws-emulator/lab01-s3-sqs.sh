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
aws sqs create-queue --queue-name curriculos-processar
aws sqs create-queue --queue-name curriculos-dlq
queue_url="$(aws sqs get-queue-url --queue-name curriculos-processar --query QueueUrl --output text)"
aws sqs send-message --queue-url "$queue_url" --message-body '{"arquivo":"teste.txt","status":"PENDENTE"}'
aws sqs receive-message --queue-url "$queue_url"
echo 'Aula 01: upload S3 e envio/recebimento SQS executados.'
