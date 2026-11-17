#!/usr/bin/env bash
# Restaura Aulas 01-07 em Ubuntu x86_64 com permissao root (KillerCoda).
# Scripts sao versionados, estado de dados e EC2 emulada nao persiste na expiração.
set -euo pipefail
lab_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$(id -u)" -ne 0 ]; then
  echo 'Execute como root no Ubuntu de laboratorio; nao use notebook corporativo sem autorizacao.' >&2
  exit 1
fi
if [ "$(uname -m)" != x86_64 ] || ! command -v apt-get >/dev/null; then
  echo 'Requer Ubuntu/Debian x86_64 com apt-get.' >&2
  exit 1
fi
echo '== 1/9 AWS Emulator, AWS CLI e Aula 01 S3/SQS =='
bash "$lab_dir/bootstrap.sh"
source "$lab_dir/env.sh"
echo '== 2/9 PostgreSQL e schema Aula 03 =='
if pg_isready -q 2>/dev/null && psql -d sre_curriculos -tAc "SELECT to_regclass('public.processed_jobs')" 2>/dev/null | grep -qx processed_jobs; then
  echo 'PostgreSQL e tabela existentes; preservando os dados.'
else
  bash "$lab_dir/aula03/install-postgres.sh"
fi
echo '== 3/9 RedrivePolicy / DLQ Aula 04 =='
bash "$lab_dir/aula04/configure-main-dlq.sh"
echo '== 4/9 API FastAPI Aula 02 em 127.0.0.1:8000 =='
start_service() {
  local name="$1" port="$2" probe="$3" match="$4" startup="$5"
  local logfile="/tmp/aws-emulator-${name}.log"
  if curl -fsS --max-time 2 "$probe" 2>/dev/null | grep -q "$match"; then
    echo "$name ja responde na porta $port."
    return
  fi
  if command -v ss >/dev/null && ss -ltn "( sport = :$port )" | grep -q LISTEN; then
    echo "ERRO: porta $port ocupada por outro servico; nao sera interrompido." >&2
    exit 1
  fi
  nohup bash "$startup" > "$logfile" 2>&1 < /dev/null &
  echo $! > "/tmp/aws-emulator-${name}.pid"
  local i
  for i in $(seq 1 45); do
    if curl -fsS --max-time 2 "$probe" 2>/dev/null | grep -q "$match"; then
      echo "$name pronto. PID $(cat "/tmp/aws-emulator-${name}.pid") / log $logfile"
      return
    fi
    sleep 1
  done
  echo "FALHA ao iniciar $name. Ultimos logs:" >&2
  tail -n 20 "$logfile" >&2 || true
  exit 1
}
start_service api 8000 http://127.0.0.1:8000/health 'aula02-api' "$lab_dir/aula02/start-api.sh"
echo '== 5/9 DynamoDB Aula 06 =='
bash "$lab_dir/aula06/run.sh"
echo '== 6/9 Workers SQS/PostgreSQL Aula 03 =='
bash "$lab_dir/aula03/start-workers.sh"
echo '== 7/9 EC2 / VPC / SG simulados Aula 05 =='
bash "$lab_dir/aula05/run.sh"
echo '== 8/9 EKS / IAM / Node Group simulados Aula 07 =='
bash "$lab_dir/aula07/run.sh"
echo '== 9/9 Console visual SOMENTE LEITURA em 8001 =='
start_service console 8001 http://127.0.0.1:8001/health 'read-only-console' "$lab_dir/aula02/start-console.sh"
echo
echo '== RESTAURACAO FINALIZADA (recursos simulados/recriados) =='
echo 'Console web: Traffic / Ports > 8001 > /console'
echo 'API interna: curl http://127.0.0.1:8000/health'
echo 'Conta ficticia: 000000000000'
echo 'DLQ Aula 04: politica recriada; teste de falha isolado e opcional via aula04/run.sh'
echo 'EKS Aula 07: cluster, nodes e Pods representados por APIs; containers NAO executam.'
echo 'AVISO: GitHub armazena scripts, NAO backups de PDF, banco ou dados volateis do AWS Emulator.'
