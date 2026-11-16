#!/usr/bin/env bash
# Inicia dois workers de processamento no fundo, sem tocar em processos de outros labs.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../env.sh"
pg_isready -q || { echo 'PostgreSQL nao esta iniciado. Execute install-postgres.sh.' >&2; exit 1; }
account="$(aws sts get-caller-identity --query Account --output text)"
test "$account" = 000000000000 || { echo 'Nao esta usando emulador AWS local' >&2; exit 1; }
venv=/tmp/aws-emulator-aula02-venv
if [ ! -x "$venv/bin/python" ]; then
  python3 -m venv "$venv"
fi
"$venv/bin/python" -m pip install --disable-pip-version-check -r "$script_dir/requirements.txt"
for worker_id in 1 2; do
  pid_file="/tmp/aws-emulator-worker-$worker_id.pid"
  log_file="/tmp/aws-emulator-worker-$worker_id.log"
  if [ -s "$pid_file" ] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    echo "Worker $worker_id ja ativo, PID $(cat "$pid_file")"
  else
    nohup "$venv/bin/python" "$script_dir/worker.py" --worker-id "$worker_id" > "$log_file" 2>&1 < /dev/null &
    echo $! > "$pid_file"
    echo "Worker $worker_id iniciado: PID $(cat "$pid_file"), log $log_file"
  fi
done
echo 'Verifique: tail -n 30 /tmp/aws-emulator-worker-1.log'
echo 'Verifique: tail -n 30 /tmp/aws-emulator-worker-2.log'
