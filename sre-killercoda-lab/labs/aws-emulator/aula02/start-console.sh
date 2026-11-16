#!/usr/bin/env bash
# Painel AWS Emulator: read-only, publicado no Killercoda em porta 8001.
set -euo pipefail
aula_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$aula_dir/../env.sh"
venv=/tmp/aws-emulator-aula02-venv
if [ ! -x "$venv/bin/python" ]; then
  echo 'Ambiente Python ausente. Primeiro execute start-api.sh da Aula 02.' >&2
  exit 1
fi
"$venv/bin/python" -m pip install --disable-pip-version-check -r "$aula_dir/requirements.txt"
"$venv/bin/python" -m pip install --disable-pip-version-check -r "$aula_dir/../aula03/requirements.txt"
echo 'Console SOMENTE LEITURA em 0.0.0.0:8001/console'
echo 'Use Traffic / Ports do Killercoda e informe 8001. NAO envie dados pessoais reais.'
exec "$venv/bin/python" -m uvicorn console_server:app --app-dir "$aula_dir" --host 0.0.0.0 --port 8001
