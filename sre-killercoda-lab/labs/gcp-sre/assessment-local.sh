#!/usr/bin/env bash
# Diagnostico inicial SRE/GKE em Kubernetes local. SOMENTE LEITURA.
# Sem autenticacao GCP, terraform apply, alteracao de cluster, criacao de recursos ou cobranca.
set -uo pipefail

title() { printf '\n=== %s ===\n' "$1"; }
check_cmd() {
  if command -v "$1" >/dev/null 2>&1; then
    printf '[OK] %-12s %s\n' "$1" "$(command -v "$1")"
  else
    printf '[AUSENTE] %s\n' "$1"
  fi
}
run_readonly() {
  printf '+ '
  printf '%q ' "$@"
  printf '\n'
  if ! "$@"; then
    echo '[AVISO] consulta indisponivel; continue a avaliacao sem modificar o ambiente.'
  fi
}

echo 'SRE LAB | Diagnostico Kubernetes -> GKE (read-only)'
echo 'Escopo: contexto Kubernetes ATUAL. Nao cria cluster/VM/recursos GCP.'
title 'FERRAMENTAS DISPONIVEIS'
for bin in bash git gh kubectl terraform gcloud; do
  check_cmd "$bin"
done

if ! command -v kubectl >/dev/null 2>&1; then
  echo 'Kubernetes nao disponivel neste terminal. Use o KillerCoda ou VM com kubectl.'
  exit 0
fi
if ! kubectl config current-context >/dev/null 2>&1; then
  echo 'Nenhum contexto kubectl configurado. Nenhuma mudanca feita.'
  exit 0
fi

title 'CONTEXTO E NOS'
run_readonly kubectl config current-context
if ! kubectl get nodes -o wide; then
  echo 'Sem acesso ao cluster. Cheque kubeconfig, RBAC e conectividade antes de continuar.'
  exit 0
fi

title 'PODS: TRIAGEM DE STATUS, RESTARTS E DISTRIBUICAO'
run_readonly kubectl get pods -A -o wide

title 'WORKLOADS E ESCALABILIDADE'
run_readonly kubectl get deployments,statefulsets -A
run_readonly kubectl get hpa -A

title 'STORAGE / PVC (PERSISTENCIA)'
run_readonly kubectl get pvc -A

title 'NAMESPACES E PERMISSOES DO USUARIO'
run_readonly kubectl get namespaces
run_readonly kubectl auth can-i list pods --all-namespaces

title 'CAPACIDADE — METRICS SERVER OPCIONAL'
if ! kubectl top nodes; then
  echo '[NOTA] Metrics Server sem acesso/indisponivel: kubectl top nao e evidencia coletada.'
fi

title 'APP FULL STACK — PRESENCA DOS COMPONENTES'
if kubectl get namespace sre-fullstack-lab >/dev/null 2>&1; then
  run_readonly kubectl -n sre-fullstack-lab get pods,svc,pvc
else
  echo 'Namespace sre-fullstack-lab nao existe neste cluster; instale via iniciar.sh se desejado.'
fi

title 'RELATORIO PARA PRATICAR GKE'
echo '1. Quais Pods estao Pending, CrashLoopBackOff ou com reinicios?'
echo '2. Qual no suporta cada Pod e quais sao os limites de CPU/memoria?'
echo '3. Existem PVCs Pending? Qual StorageClass e usada?'
echo '4. Quem tem privilegio para ler/escrever no namespace?'
echo '5. Se fosse GKE, qual seria o impacto de node pool, autoscaling e IAM?'
echo '6. Defina uma hipotese, evidencias, mitigacao e rollback.'
echo 'RESULTADO: auditoria read-only finalizada; nenhum recurso foi alterado.'
