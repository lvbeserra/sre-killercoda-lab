#!/usr/bin/env bash
# Aula SRE: produzir e consumir mensagens FICTICIAS em Kafka e RabbitMQ.
# Sem dados reais, sem processamento de pagamentos e sem alterar serviços de produção.
set -euo pipefail
cd "$(dirname "$0")/.."
NS=sre-middleware-lab
for bin in kubectl curl python3 base64; do
  command -v "$bin" >/dev/null || { echo "ERRO: $bin ausente" >&2; exit 1; }
done
for svc in apache kafka rabbitmq; do
  kubectl -n "$NS" rollout status "deployment/$svc" --timeout=45s
done

echo "=== TESTE 1: KAFKA / pagamentos-simulados ==="
KAFKA=/opt/kafka/bin
kubectl -n "$NS" exec deploy/kafka -- "$KAFKA/kafka-topics.sh" \
  --bootstrap-server kafka:9092 --create --if-not-exists \
  --topic pagamentos-simulados --partitions 1 --replication-factor 1 >/dev/null
# Pega o próximo offset ANTES de publicar para consumir exatamente esta mensagem.
NEXT_OFFSET=$(kubectl -n "$NS" exec deploy/kafka -- "$KAFKA/kafka-get-offsets.sh" \
  --bootstrap-server kafka:9092 --topic pagamentos-simulados --time -1 |
  awk -F: '$2 == "0" {print $3; exit}')
[[ "$NEXT_OFFSET" =~ ^[0-9]+$ ]] || { echo "ERRO: offset Kafka inválido: $NEXT_OFFSET" >&2; exit 1; }
STAMP=$(date -u '+%Y%m%dT%H%M%SZ')
PAYMENT_ID="PAG-LAB-$STAMP"
EVENT=$(printf '{"pagamento_id":"%s","valor_centavos":1234,"status":"APROVADO_SIMULADO"}' "$PAYMENT_ID")
printf '%s\n' "$EVENT" |
  kubectl -n "$NS" exec -i deploy/kafka -- "$KAFKA/kafka-console-producer.sh" \
    --bootstrap-server kafka:9092 --topic pagamentos-simulados
RECEIVED=$(kubectl -n "$NS" exec deploy/kafka -- "$KAFKA/kafka-console-consumer.sh" \
  --bootstrap-server kafka:9092 --topic pagamentos-simulados \
  --partition 0 --offset "$NEXT_OFFSET" --max-messages 1 --timeout-ms 20000)
printf 'Evento Kafka recebido: %s\n' "$RECEIVED"
printf '%s' "$RECEIVED" | grep -Fq "$PAYMENT_ID" || {
  echo "ERRO: não consumimos o evento que acabamos de publicar." >&2; exit 1;
}

echo "=== TESTE 2: RABBITMQ / notificações simuladas ==="
# Port-forward LOCAL temporário, sem expor Management API publicamente.
PF_LOG=$(mktemp)
PF_PID=""
cleanup() {
  if [[ -n "$PF_PID" ]]; then kill "$PF_PID" 2>/dev/null || true; fi
  rm -f "$PF_LOG"
}
trap cleanup EXIT
kubectl -n "$NS" port-forward service/rabbitmq 18172:15672 --address 127.0.0.1 \
  >"$PF_LOG" 2>&1 &
PF_PID=$!
for i in $(seq 1 30); do
  if curl -sS --max-time 1 -o /dev/null http://127.0.0.1:18172/api/overview 2>/dev/null; then
    break
  fi
  sleep 1
done
kill -0 "$PF_PID" 2>/dev/null || { cat "$PF_LOG" >&2; exit 1; }

# O Secret só entra na memória. Credencial não aparece em argumento de processo,
# log, repositório nem URL. Curl lê configuração pelo stdin.
PASS=$(kubectl -n "$NS" get secret rabbitmq-auth -o jsonpath='{.data.password}' | base64 -d)
rabbit_api() {
  printf 'user = "labuser:%s"\n' "$PASS" |
    curl -K - --silent --show-error --fail-with-body --max-time 15 "$@"
}
QUEUE="notificacoes-teste-$STAMP"
BASE=http://127.0.0.1:18172/api
rabbit_api -X PUT -H 'Content-Type: application/json' \
  --data '{"durable":false,"auto_delete":false,"arguments":{}}' \
  "$BASE/queues/%2F/$QUEUE" >/dev/null
PUB_DATA=$(printf '{"properties":{},"routing_key":"%s","payload":"Notificacao LAB %s","payload_encoding":"string"}' "$QUEUE" "$PAYMENT_ID")
ROUTED=$(rabbit_api -X PUT -H 'Content-Type: application/json' \
  --data "$PUB_DATA" "$BASE/exchanges/%2F/amq.default/publish")
printf '%s' "$ROUTED" | python3 -c 'import json,sys; r=json.load(sys.stdin); assert r.get("routed") is True, "Mensagem não roteada"'
RESULT=$(rabbit_api -X POST -H 'Content-Type: application/json' \
  --data '{"count":1,"ackmode":"ack_requeue_false","encoding":"auto"}' \
  "$BASE/queues/%2F/$QUEUE/get")
printf '%s' "$RESULT" |
  python3 -c 'import json,sys; x=json.load(sys.stdin); assert len(x)==1 and "Notificacao LAB" in x[0]["payload"], x; print("Mensagem RabbitMQ recebida:", x[0]["payload"])'
rabbit_api -X DELETE "$BASE/queues/%2F/$QUEUE" >/dev/null
unset PASS
echo "SUCESSO: Kafka e RabbitMQ produziram e consumiram mensagens de teste."
echo "NOTA: o fluxo Kafka -> RabbitMQ ainda exige uma aplicação bridge; este script testa os serviços separadamente."
