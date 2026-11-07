#!/usr/bin/env bash
set -euo pipefail
NS=sre-release-lab
printf '\n== CONTEXTO / NODES ==\n'
kubectl config current-context
kubectl get nodes
printf '\n== DEPLOYMENTS E PODS ==\n'
kubectl -n "$NS" get deployments,pods -o wide
printf '\n== SERVICE / ENDPOINTS ==\n'
kubectl -n "$NS" get services,endpointslices -o wide
printf '\n== DNS ABSOLUTO ==\n'
kubectl -n "$NS" exec deploy/web-blue -- nslookup sre-web.sre-release-lab.svc.cluster.local.
printf '\n== HTTP BLUE (esperado versao=blue-v1) ==\n'
kubectl -n "$NS" exec deploy/web-blue -- wget -qO- http://sre-web
printf '\n== HTTP GREEN (esperado versao=green-v2) ==\n'
kubectl -n "$NS" exec deploy/web-blue -- wget -qO- http://sre-web-green
printf '\n== HTTP DRAIN (esperado READY) ==\n'
kubectl -n "$NS" exec deploy/web-blue -- wget -qO- http://drain-demo/ready
printf '\n== MAPA DE SERVICOS CILIUM ==\n'
SVC_IP=$(kubectl -n "$NS" get svc sre-web -o jsonpath='{.spec.clusterIP}')
echo "ClusterIP=$SVC_IP"
# O mapa eBPF pode variar conforme o cenario; nao falhar se a CLI estiver ausente.
kubectl -n kube-system exec ds/cilium -- cilium-dbg service list 2>/dev/null | grep -A 3 "$SVC_IP" || true
printf '\n== METRICS API (opcional) ==\n'
kubectl get apiservice v1beta1.metrics.k8s.io --ignore-not-found
printf '\nValidacao terminada. Leia docs/PROGRESSO.md para a proxima aula.\n'
