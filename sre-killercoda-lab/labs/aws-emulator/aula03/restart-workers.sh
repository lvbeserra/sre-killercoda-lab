#!/usr/bin/env bash
# Reinicia somente os dois workers identificados do proprio laboratorio.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for worker_id in 1 2; do
  pid_file="/tmp/aws-emulator-worker-$worker_id.pid"
  if [ ! -s "$pid_file" ]; then continue; fi
  pid="$(cat "$pid_file")"
  if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    echo "PID invalido no $pid_file, abortando." >&2
    exit 1
  fi
  if [ ! -r "/proc/$pid/cmdline" ]; then
    echo "Worker $worker_id ja encerrado (PID $pid)."
    continue
  fi
  cmd="$(tr '\0' ' ' < "/proc/$pid/cmdline")"
  case "$cmd" in
    *"$script_dir/worker.py --worker-id $worker_id"*)
      echo "Encerrando worker $worker_id PID $pid"
      kill -TERM "$pid"
      ;;
    *)
      echo "PID $pid nao pertence ao worker $worker_id deste lab; abortando." >&2
      exit 1
      ;;
  esac
done
for worker_id in 1 2; do
  pid_file="/tmp/aws-emulator-worker-$worker_id.pid"
  [ -s "$pid_file" ] || continue
  pid="$(cat "$pid_file")"
  for attempt in $(seq 1 15); do
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 1
  done
  if kill -0 "$pid" 2>/dev/null; then
    echo "Worker $worker_id ainda ativo, nao sobrescrevendo nem forcando parada." >&2
    exit 1
  fi
done
bash "$script_dir/start-workers.sh"
