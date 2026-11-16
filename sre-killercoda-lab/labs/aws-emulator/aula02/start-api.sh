#!/usr/bin/env bash
# Aula 02: inicia a API local FastAPI conectada SOMENTE ao AWS Emulator.
set -euo pipefail
aula_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$aula_dir/../env.sh"
if ! command -v python3 >/dev/null 2>&1; then
  echo 'Python3 ausente: instale pelo apt antes de continuar.' >&2
  exit 1
fi
venv=/tmp/aws-emulator-aula02-venv
if [ ! -x "$venv/bin/python" ]; then
  if ! python3 -m venv "$venv"; then
    echo 'Falhou criar venv. No Ubuntu, instale python3-venv pelo apt e tente novamente.' >&2
    exit 1
  fi
fi
"$venv/bin/python" -m pip install --disable-pip-version-check -r "$aula_dir/requirements.txt"
echo 'API iniciando em http://127.0.0.1:8000'
echo 'Abrir outro terminal para curl e testes. Ctrl+C para parar a API.'
exec "$venv/bin/python" -m uvicorn api:app --app-dir "$aula_dir" --host 127.0.0.1 --port 8000
