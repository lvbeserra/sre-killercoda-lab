#!/usr/bin/env bash
set -euo pipefail
NS=sre-middleware-lab
kubectl -n "$NS" get pods,svc -o wide
kubectl -n "$NS" exec deploy/apache -- wget -qO- http://apache | head -c 500
echo
kubectl -n "$NS" exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists --topic pagamentos-simulados --partitions 1 --replication-factor 1
kubectl -n "$NS" exec deploy/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic pagamentos-simulados
kubectl -n "$NS" exec deploy/rabbitmq -- rabbitmq-diagnostics -q ping
