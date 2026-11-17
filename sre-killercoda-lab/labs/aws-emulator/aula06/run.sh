#!/usr/bin/env bash
# Aula 06 DynamoDB: operações isoladas na conta ficticia AWS Emulator.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$lab_dir/../env.sh"
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "${AWS_ENDPOINT_URL:-}" != https://127.0.0.1:9297 ] || [ "$account" != 000000000000 ]; then
  echo 'ABORTADO: somente AWS Emulator local, conta 000000000000.' >&2
  exit 1
fi
table=sre-lab-jobs
if aws dynamodb describe-table --table-name "$table" >/dev/null 2>&1; then
  echo "Tabela existente: $table (dados preservados)"
else
  aws dynamodb create-table \
    --table-name "$table" \
    --attribute-definitions AttributeName=job_id,AttributeType=S \
    --key-schema AttributeName=job_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --query 'TableDescription.[TableName,TableStatus]' --output json
fi
aws dynamodb wait table-exists --table-name "$table"
echo 'Status da tabela:'
aws dynamodb describe-table --table-name "$table" --query 'Table.[TableName,TableStatus,ItemCount]' --output json
item_present="$(aws dynamodb get-item --table-name "$table" --key '{"job_id":{"S":"JOB-001"}}' --query 'Item.job_id.S' --output text)"
if [ "$item_present" = JOB-001 ]; then
  echo 'JOB-001 ja existe; registro preservado.'
else
  aws dynamodb put-item --table-name "$table" --item '{"job_id":{"S":"JOB-001"},"status":{"S":"PROCESSADO"},"worker":{"S":"worker-1"},"arquivo":{"S":"curriculo-ficticio.pdf"},"tentativas":{"N":"1"}}'
  echo 'JOB-001 ficticio inserido.'
fi
aws dynamodb get-item --table-name "$table" --key '{"job_id":{"S":"JOB-001"}}' --output json
echo 'Aula 06: Create/Describe/Put/Get validos no emulador. Scan manual opcional.'
