#!/usr/bin/env bash
# Inicie este script ao abrir cada sessão KillerCoda; checkpoints a cada 50 minutos.
set -euo pipefail
cd "$(dirname "$0")"
PIDFILE="/tmp/sre-checkpoints.pid"
LOGFILE="/tmp/sre-checkpoints.log"
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "Monitor já ativo, PID $(cat "$PIDFILE")."
  exit 0
fi
# Inicia com checkpoint imediato; os seguintes ocorrem a cada 3000 segundos.
nohup bash -c '
  cd "$1"
  while true; do
    bash checkpoint.sh >> /tmp/sre-checkpoints.log 2>&1 || echo "Falhou: ver /tmp/sre-checkpoints.log" >> /tmp/sre-checkpoints.log
    sleep 3000
  done
' _ "$PWD" >/dev/null 2>&1 </dev/null &
echo $! > "$PIDFILE"
echo "Checkpoint iniciado: PID $(cat "$PIDFILE"); intervalo 50 min."
echo "Confira a publicação com: tail -30 $LOGFILE"
echo "Atenção: parar com kill $(cat "$PIDFILE") (apenas se desejar)."
