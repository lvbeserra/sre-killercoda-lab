#!/usr/bin/env bash
# Aula 04: DLQ e 3 tentativas, em duas filas isoladas.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$lab_dir/../env.sh"
venv=/tmp/aws-emulator-aula02-venv
if [ ! -x "$venv/bin/python" ]; then
  echo 'Ambiente Python ausente; execute a Aula 02 primeiro.' >&2
  exit 1
fi
"$venv/bin/python" -m pip install --disable-pip-version-check 'boto3>=1.35,<2'
"$venv/bin/python" "$lab_dir/test-dlq.py"
