#!/usr/bin/env bash
# Aula Control-M 01: executor Shell DIDATICO (NAO e Control-M real).
# Somente dados ficticios em /tmp; nenhuma alteracao no cluster Kubernetes.
set -euo pipefail
umask 077

SIMULAR_FALHA=0
case "${1:-}" in
  "") ;;
  --falhar) SIMULAR_FALHA=1 ;;
  *) echo "Uso: bash $0 [--falhar]" >&2; exit 2 ;;
esac

BASE="${TMPDIR:-/tmp}/controlm-lab-$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BASE"
echo "=== CONTROL-M: SIMULACAO DE JOBS (NAO E PRODUTO BMC) ==="
echo "Evidencias: $BASE"

precheck() {
  command -v awk >/dev/null
  command -v date >/dev/null
  printf 'UTC: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'Prechecks do ambiente: OK\n'
}

processar() {
  if [[ "$SIMULAR_FALHA" -eq 1 ]]; then
    echo "ERRO INTENCIONAL: rotina ETL interrompida antes de gerar resultado" >&2
    return 42
  fi
  printf 'id,status\n1,OPEN\n2,INVESTIGATING\n3,RESOLVED\n' > "$BASE/incidentes-ficticios.csv"
  echo "Arquivo de testes gerado: 3 incidentes FICTICIOS"
}

validar() {
  local arquivo="$BASE/incidentes-ficticios.csv"
  [[ -s "$arquivo" ]] || { echo "ERRO: arquivo inexistente ou vazio" >&2; return 21; }
  local linhas
  linhas="$(awk 'END{print NR-1}' "$arquivo")"
  [[ "$linhas" -eq 3 ]] || { echo "ERRO: esperadas 3 linhas, encontrado $linhas" >&2; return 22; }
  echo "Validacao: 3 registros ficticios. OK"
}

executar_job() {
  local nome="$1"
  shift
  local arquivo_log="$BASE/$nome.log"
  echo "INICIANDO $nome"
  local rc
  if "$@" >"$arquivo_log" 2>&1; then
    echo "END OK     $nome  (log: $arquivo_log)"
    return 0
  else
    rc="$?"
    echo "END NOTOK  $nome  (ExitCode=$rc; log: $arquivo_log)"
    return "$rc"
  fi
}

executar_job JOB_01_PRECHECK precheck || exit $?
if executar_job JOB_02_PROCESSAMENTO processar; then
  :
else
  rc="$?"
  echo "JOB_03_VALIDACAO: WAIT/BLOQUEADO - JOB_02 nao terminou OK"
  echo "Consulte: $BASE/JOB_02_PROCESSAMENTO.log"
  exit "$rc"
fi
executar_job JOB_03_VALIDACAO validar || exit $?
echo "SUCESSO: cadeia de 3 jobs finalizada."
echo "Consultar logs: ls -l '$BASE' && cat '$BASE'/JOB_*.log"
