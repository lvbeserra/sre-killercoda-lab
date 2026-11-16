#!/usr/bin/env bash
# Configura a DLQ real do LAB (ambiente emulado). Nao apaga mensagens.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$lab_dir/../env.sh"
account="$(aws sts get-caller-identity --query Account --output text)"
[ "$account" = 000000000000 ] || { echo 'ABORTADO: conta nao emulada' >&2; exit 1; }
queue_url="$(aws sqs get-queue-url --queue-name curriculos-processar --query QueueUrl --output text)"
dlq_url="$(aws sqs get-queue-url --queue-name curriculos-dlq --query QueueUrl --output text)"
dlq_arn="$(aws sqs get-queue-attributes --queue-url "$dlq_url" --attribute-names QueueArn --query Attributes.QueueArn --output text)"
attributes="$(python3 -c 'import json,sys;print(json.dumps({"RedrivePolicy":json.dumps({"deadLetterTargetArn":sys.argv[1],"maxReceiveCount":"3"})}))' "$dlq_arn")"
aws sqs set-queue-attributes --queue-url "$queue_url" --attributes "$attributes"
aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names RedrivePolicy --output json
echo 'DLQ configurada na fila curriculos-processar. Mensagens existentes preservadas.'
