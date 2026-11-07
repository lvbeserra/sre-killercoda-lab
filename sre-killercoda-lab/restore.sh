#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

printf '\n== SRE LAB: checagem de contexto ==\n'
kubectl config current-context
kubectl get nodes -o wide
printf '\nATENCAO: este script altera apenas namespaces de laboratorio (sre-release-lab e sre-cpu-lab).\n'

printf '\n== Aplicando YAML declarativo ==\n'
kubectl apply -f lab-completo.yaml

printf '\n== Aguardando Blue / Green / Drain ==\n'
kubectl -n sre-release-lab rollout status deployment/web-blue --timeout=180s
kubectl -n sre-release-lab rollout status deployment/web-green --timeout=180s
kubectl -n sre-release-lab rollout status deployment/drain-demo --timeout=180s

printf '\n== Estado ==\n'
kubectl -n sre-release-lab get deploy,pod,svc -o wide
printf '\nPronto. Para validar HTTP, execute: bash validate.sh\n'
