# CHECKPOINT DO CURSO — 07/11/2026

## Atualização validada — 07/11/2026: Rollout e GitHub
- Repositório público `lvbeserra/sre-killercoda-lab` clonado e restaurado com `bash restore.sh`; `bash validate.sh` confirmou DNS e HTTP Blue/Green/Drain.
- Novo cenário com **2 nós Ready**: `controlplane` e `node01`; `web-blue` com 2 réplicas distribuídas, `web-green` 1, `drain-demo` 2 réplicas distribuídas.
- Rolling Update executado com `maxUnavailable=0` e `maxSurge=1`, 120 consultas HTTP GET `/ready` durante `rollout restart`: **120 OK, 0 FAIL, CLIENT_EXIT_CODE=0**.
- Novos Pods `drain-demo-5577f764d7-2ts7j` em `controlplane` e `drain-demo-5577f764d7-cr99v` em `node01`, ambos 1/1 Ready ao fim; antigos encerrados com status Completed.
- O teste cobre requisições curtas observadas, NÃO garante zero downtime universal nem testa `/slow` durante rollout.
- Scripts `checkpoint.sh` e `start-checkpoints.sh` adicionados. A cada sessão, iniciar monitor 50 minutos; push automático requer autenticação Git segura **sem** armazenar token no repositório.
- **Próxima aula**: teste de `/slow` concorrente com Rolling Update e coleta por Pod, endpoints e logs; depois políticas Cilium, multi-node, Istio/Canary.

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

## Checkpoint da sessão — 2026-11-07 13:05:25 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2d1h   v1.37.1
node01         Ready    <none>          2d1h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           11m   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           11m   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           11m   web          busybox:1.36         app=sre-web,track=green

NAME                              READY   STATUS    RESTARTS   AGE     IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-5577f764d7-2ts7j   1/1     Running   0          7m20s   192.168.0.135   controlplane   <none>           <none>
pod/drain-demo-5577f764d7-cr99v   1/1     Running   0          7m32s   192.168.1.99    node01         <none>           <none>
pod/web-blue-5c57468c74-54lk4     1/1     Running   0          11m     192.168.0.220   controlplane   <none>           <none>
pod/web-blue-5c57468c74-6htx6     1/1     Running   0          11m     192.168.1.27    node01         <none>           <none>
pod/web-green-6654db8d7b-h4vfv    1/1     Running   0          11m     192.168.1.253   node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.100.188.83    <none>        80/TCP    11m   app=drain-demo
service/sre-web         ClusterIP   10.106.203.207   <none>        80/TCP    11m   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.145.199   <none>        80/TCP    11m   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-4g49z      IPv4          8080    192.168.1.99,192.168.0.135   11m
sre-web-green-mpwqh   IPv4          8080    192.168.1.253                11m
sre-web-vkjpl         IPv4          8080    192.168.0.220,192.168.1.27   11m
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Checkpoint da sessão — 2026-11-07 13:07:17 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2d1h   v1.37.1
node01         Ready    <none>          2d1h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           12m   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           12m   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           12m   web          busybox:1.36         app=sre-web,track=green

NAME                              READY   STATUS    RESTARTS   AGE     IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-5577f764d7-2ts7j   1/1     Running   0          9m13s   192.168.0.135   controlplane   <none>           <none>
pod/drain-demo-5577f764d7-cr99v   1/1     Running   0          9m25s   192.168.1.99    node01         <none>           <none>
pod/web-blue-5c57468c74-54lk4     1/1     Running   0          12m     192.168.0.220   controlplane   <none>           <none>
pod/web-blue-5c57468c74-6htx6     1/1     Running   0          12m     192.168.1.27    node01         <none>           <none>
pod/web-green-6654db8d7b-h4vfv    1/1     Running   0          12m     192.168.1.253   node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.100.188.83    <none>        80/TCP    12m   app=drain-demo
service/sre-web         ClusterIP   10.106.203.207   <none>        80/TCP    12m   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.145.199   <none>        80/TCP    12m   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-4g49z      IPv4          8080    192.168.1.99,192.168.0.135   12m
sre-web-green-mpwqh   IPv4          8080    192.168.1.253                12m
sre-web-vkjpl         IPv4          8080    192.168.0.220,192.168.1.27   12m
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Checkpoint da sessão — 2026-11-07 13:17:31 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2d1h   v1.37.1
node01         Ready    <none>          2d1h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           23m   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           23m   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           23m   web          busybox:1.36         app=sre-web,track=green

NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-5577f764d7-2ts7j   1/1     Running   0          19m   192.168.0.135   controlplane   <none>           <none>
pod/drain-demo-5577f764d7-cr99v   1/1     Running   0          19m   192.168.1.99    node01         <none>           <none>
pod/web-blue-5c57468c74-54lk4     1/1     Running   0          23m   192.168.0.220   controlplane   <none>           <none>
pod/web-blue-5c57468c74-6htx6     1/1     Running   0          23m   192.168.1.27    node01         <none>           <none>
pod/web-green-6654db8d7b-h4vfv    1/1     Running   0          23m   192.168.1.253   node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.100.188.83    <none>        80/TCP    23m   app=drain-demo
service/sre-web         ClusterIP   10.106.203.207   <none>        80/TCP    23m   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.145.199   <none>        80/TCP    23m   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-4g49z      IPv4          8080    192.168.1.99,192.168.0.135   23m
sre-web-green-mpwqh   IPv4          8080    192.168.1.253                23m
sre-web-vkjpl         IPv4          8080    192.168.0.220,192.168.1.27   23m
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Checkpoint da sessão — 2026-11-07 13:23:07 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2d2h   v1.37.1
node01         Ready    <none>          2d1h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           28m   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           28m   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           28m   web          busybox:1.36         app=sre-web,track=green

NAME                              READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-5577f764d7-2ts7j   1/1     Running   0          25m   192.168.0.135   controlplane   <none>           <none>
pod/drain-demo-5577f764d7-cr99v   1/1     Running   0          25m   192.168.1.99    node01         <none>           <none>
pod/web-blue-5c57468c74-54lk4     1/1     Running   0          28m   192.168.0.220   controlplane   <none>           <none>
pod/web-blue-5c57468c74-6htx6     1/1     Running   0          28m   192.168.1.27    node01         <none>           <none>
pod/web-green-6654db8d7b-h4vfv    1/1     Running   0          28m   192.168.1.253   node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.100.188.83    <none>        80/TCP    28m   app=drain-demo
service/sre-web         ClusterIP   10.106.203.207   <none>        80/TCP    28m   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.145.199   <none>        80/TCP    28m   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-4g49z      IPv4          8080    192.168.1.99,192.168.0.135   28m
sre-web-green-mpwqh   IPv4          8080    192.168.1.253                28m
sre-web-vkjpl         IPv4          8080    192.168.0.220,192.168.1.27   28m
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.
