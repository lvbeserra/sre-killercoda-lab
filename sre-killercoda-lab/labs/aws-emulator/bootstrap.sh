#!/usr/bin/env bash
# Recupera a Aula 01 AWS Emulator em Ubuntu/KillerCoda novo.
# Instalacao de pacotes exige root ou sudo. Nao usa credenciais AWS reais.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(uname -m)" != 'x86_64' ] || ! command -v apt-get >/dev/null 2>&1; then
  echo 'Este bootstrap requer Ubuntu/Debian x86_64.' >&2
  exit 1
fi
echo '== 1/5: AWS Emulator =='
if ! command -v aws-emulator >/dev/null 2>&1; then
  bash "$script_dir/install-ubuntu.sh"
else
  aws-emulator -v
fi
echo '== 2/5: AWS CLI v2 =='
if ! command -v aws >/dev/null 2>&1 || ! aws --version 2>&1 | grep -q 'aws-cli/2'; then
  curl -fsSLo /tmp/aws-emulator-install-awscli.sh https://awscli.amazonaws.com/v2/install.sh
  if [ "$(id -u)" = 0 ]; then
    bash /tmp/aws-emulator-install-awscli.sh --system
  else
    sudo bash /tmp/aws-emulator-install-awscli.sh --system
  fi
fi
export PATH="/usr/local/bin:$HOME/.local/bin:$PATH"
aws --version
echo '== 3/5: Inicializar endpoint local =='
emulator_dir="$HOME/.aws/emulator/9297"
health_url=https://127.0.0.1:9297/__admin/health
emulator_healthy() {
  [ -s "$emulator_dir/emulator_credentials" ] && [ -s "$emulator_dir/ca.pem" ] &&
    curl -fsS --max-time 2 --cacert "$emulator_dir/ca.pem" "$health_url" >/dev/null
}
if emulator_healthy; then
  echo 'Emulador ja esta ativo.'
else
  if command -v ss >/dev/null 2>&1 && ss -ltn '( sport = :9297 )' | grep -q LISTEN; then
    echo 'Porta 9297 ocupada por outro processo; nao alterarei o servico existente.' >&2
    exit 1
  fi
  nohup aws-emulator --telemetry off > /tmp/aws-emulator.log 2>&1 < /dev/null &
  for attempt in $(seq 1 30); do
    if emulator_healthy; then break; fi
    sleep 1
  done
  if ! emulator_healthy; then
    echo 'Falha ao inicializar AWS Emulator. Log:' >&2
    tail -n 30 /tmp/aws-emulator.log >&2 || true
    exit 1
  fi
fi
echo '== 4/5: Ativar somente credenciais emuladas =='
source "$script_dir/env.sh"
account="$(aws sts get-caller-identity --query Account --output text)"
if [ "$account" != '000000000000' ]; then
  echo "ABORTADO: Account=$account nao e a conta emulada." >&2
  exit 1
fi
echo '== 5/5: Recriar S3 e SQS da Aula 01 =='
bash "$script_dir/lab01-s3-sqs.sh"
echo
echo 'Aula 01 AWS Emulator restaurada. Estado temporario, salvo apenas enquanto emulador estiver ativo.'
echo "Para usar AWS CLI nesta janela: source '$script_dir/env.sh'"
