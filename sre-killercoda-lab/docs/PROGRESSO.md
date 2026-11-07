# CHECKPOINT DO CURSO — 07/11/2026

## Ambiente observado
- KillerCoda / cluster Kubernetes single-node, Ubuntu 24.04.5, v1.37.1; 1 vCPU, ~2.2 GiB RAM, ~20 GB disco.
- Rede com Cilium v1.20.3, `KubeProxyReplacement: True`, `Backend Selection: Random`, `Socket LB: Enabled` conforme status em runtime; configmap mostrava bpf-lb-sock false, divergência ainda não explicada em definitivo.
- Cilium usa VXLAN configurado; somente 1 node, portanto encapsulamento inter-node ainda NÃO testado.
- Sem políticas de NetworkPolicy/CiliumNetworkPolicy no laboratório observado; endpoints `ingress/egress: Disabled`.
- Há uma reinicialização/expiração de cenário anterior; namespaces `sre-release-lab` e `sre-cpu-lab` se perderam, e Metrics Server também; laboratório de aplicação foi recriado.

## Trabalhos concluídos / evidências
1. Linux: ~70–78% CPU idle na coleta; memória ~953 MiB available; disco / ~61% em sessão anterior.
2. Metrics API inicialmente ausente; Metrics Server v0.9.0 instalado manualmente; falhou porque kubelet em 172.30.1.2:10250 tinha SAN DNS:controlplane mas não IP SAN. Exceção `--kubelet-insecure-tls` usada APENAS no ambiente descartável para teste; após reinício do KillerCoda, Metrics Server não permaneceu.
3. CPU throttling testado com busybox: 100m consumiu ~101m; throttling em 315/357 períodos; 300m consumiu ~299m; throttling 388/438. A tarefa SHA-256 de 128MiB completou em **16s com 100m** e **5s com 300m**. Isso comprova melhora em tarefa CPU-bound, não latência de API.
4. Blue-Green: versão Blue v1 atrás de `sre-web`; versão Green v2 testada após corrigir readiness `/ready` inexistente para `/`. Transição de selector planejada, mas não há evidência de execução dessa etapa antes da expiração.
5. DNS: FQDN absoluto de `sre-web.sre-release-lab.svc.cluster.local.` resolveu; HTTP retornou `versao=blue-v1`.
6. Cilium eBPF: Service original 10.107.192.27:80 encaminhava para backend 192.168.0.175:8080; após escalar Blue para 2, backends .71 e .175 ativos no BPF. Pods compartilhavam security identity 25761. IPs são históricos e NÃO devem ser codificados nos manifests.
7. Distribuição HTTP: 30 requisições /pod-id = 10 para um Pod e 20 para outro. Balanceamento não necessariamente uniforme.
8. Scale down para 1: EndpointSlice exibiu antigo `ready=false, serving=true, terminating=true`; Cilium exibiu backend terminating e outro active. Depois antigo foi removido; scale-up criou novo Pod.
9. Graceful shutdown: Python `GET /slow` dura 12s. Na exclusão do Pod, logs apresentaram REQUEST_START 12:13:20.836, SIGTERM_RECEIVED 12:13:26.325, REQUEST_END 12:13:32.838, GRACEFUL_EXIT 12:13:32.846 UTC; cliente recebeu `COMPLETED pod=...`, EXIT_CODE=0. Demonstrada preservação da requisição original; NÃO comprovada disponibilidade contínua.
10. Última aula: `drain-demo` foi escalado para `replicas: 2`, rollingUpdate `maxUnavailable: 0`, `maxSurge: 1`. Pods prontos e zero restarts.

## ESTADO DESEJADO PRESERVADO NO YAML
- `sre-release-lab`: `web-blue` x2, `web-green` x1, `drain-demo` x2, ConfigMap e três Services.
- `sre-cpu-lab`: namespace reservado, sem jobs executando por padrão.
- Services recebem ClusterIPs novos e Pods recebem novos IPs a cada sessão.

## PRÓXIMA AULA: rolling update com tráfego
1. Restaurar e verificar: `bash restore.sh && bash validate.sh`.
2. Criar cliente HTTP leve com chamadas a `http://drain-demo/ready` (120 requisições) e contagem OK / FAIL. Cliente deve ser `web-blue`, não o Deployment em rollout.
3. Executar `kubectl -n sre-release-lab rollout restart deployment/drain-demo` durante as requisições.
4. Observar Pods/ReplicaSets/EndpointSlices e logs. Critério: 2 réplicas disponíveis após o rollout e falhas HTTP correlacionadas (se houver).
5. Depois testar conexões longas `/slow` durante rollout, fechar com análise de SLI, SLO, availability e FinOps.
6. Futuros temas: canary 10/25/50/100, Istio/Envoy/mTLS (ambiente maior), RBAC, NetworkPolicy, Cilium, Prometheus/Grafana, Argo CD, Kubernetes deep internals, LPIC-2, CI/CD e FinOps.

## Mudanças futuras
Sempre que evoluir o laboratório, atualizar `lab-completo.yaml` (estado desejado) **e** este arquivo (progresso). Commits no GitHub serão o histórico auditável.
