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

## Checkpoint da sessão — 2026-11-07 20:38:51 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE    VERSION
controlplane   Ready    control-plane   2d9h   v1.37.1
node01         Ready    <none>          2d8h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           4m57s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           4m57s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           4m57s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE     IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-rxqpk   1/1     Running   0          4m56s   192.168.0.241   controlplane   <none>           <none>
pod/drain-demo-89554557b-s89tk   1/1     Running   0          4m57s   192.168.1.87    node01         <none>           <none>
pod/web-blue-5c57468c74-5mbrt    1/1     Running   0          4m57s   192.168.0.9     controlplane   <none>           <none>
pod/web-blue-5c57468c74-rkdjm    1/1     Running   0          4m57s   192.168.1.166   node01         <none>           <none>
pod/web-green-6654db8d7b-xfnvm   1/1     Running   0          4m57s   192.168.1.32    node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE     SELECTOR
service/drain-demo      ClusterIP   10.99.84.69     <none>        80/TCP    4m57s   app=drain-demo
service/sre-web         ClusterIP   10.110.78.240   <none>        80/TCP    4m57s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.22.245   <none>        80/TCP    4m57s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-zzszx      IPv4          8080    192.168.0.241,192.168.1.87   4m56s
sre-web-fwf5q         IPv4          8080    192.168.0.9,192.168.1.166    4m57s
sre-web-green-rxdd2   IPv4          8080    192.168.1.32                 4m57s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Verificação middleware — 07/11/2026 (saída enviada pelo aluno)
- Kubernetes v1.37.1 com **controlplane e node01 Ready**.
- `sre-middleware-lab`: Apache HTTP, Kafka e RabbitMQ, todos **1/1 Running, zero restarts** no momento da coleta.
- Apache: requisição HTTP interna retornou a página de demonstração.
- Kafka: tópico `pagamentos-simulados`, 1 partição, leader 1, replicas 1, ISR 1. **Tópico verificado, ainda sem evento de teste consumido nessa coleta.**
- RabbitMQ: `rabbitmq-diagnostics -q ping` respondeu `Ping succeeded`; imagem 4.1-management corrigida com `rabbitmq.conf` via ConfigMap e startup/readiness TCP 5672.
- GitHub: `checkpoint.sh` publicou commit `0f1772e` e `git status -sb` confirmou `main...origin/main` naquele momento; a execução autônoma após 50 minutos **não foi observada ainda**.
- Recursos (primeiro / segundo nó respectivamente): CPU requests 365m(36%) / 470m(47%); CPU limits 1200m(120%) / 3050m(305%); memory requests 258Mi(12%) / 802Mi(44%); memory limits 1556Mi(72%) / 3424Mi(189%). Esses são somatórios de requests/limits, não consumo real.
- Adicionado `labs/test-mensageria.sh`: teste reprodutível de produção e consumo separado de eventos fictícios Kafka + notificações RabbitMQ. **Ainda não há integração app Kafka → RabbitMQ nem Dynatrace instalado.**
- Próxima aula: executar `bash sre-killercoda-lab/labs/test-mensageria.sh` a partir da raiz do clone, verificar retorno e então criar bridge e observabilidade.

## Checkpoint de aula — 07/11/2026 20:54 UTC: mensageria validada
- `bash sre-killercoda-lab/labs/test-mensageria.sh` concluído com sucesso.
- Kafka: produzido e consumido 1 evento fictício `{"pagamento_id":"PAG-LAB-20261107T205423Z","valor_centavos":1234,"status":"APROVADO_SIMULADO"}`; CLI relatou `Processed a total of 1 messages`.
- RabbitMQ: publicado e consumido `Notificacao LAB PAG-LAB-20261107T205423Z`; script concluiu com `SUCESSO`.
- **Esses dois testes foram independentes**; ainda não comprovavam integração automática Kafka → RabbitMQ.
- Adicionados `apps/payment-bridge/bridge.py`, `requirements.txt`, `labs/payment-bridge.yaml`, `labs/restore-payment-bridge.sh` e `labs/test-bridge.sh`. Objetivo: consumir pagamentos simulados no Kafka, publicar notificações no RabbitMQ com publisher confirms, e só então commitar offsets Kafka.
- Inicializador `setup.sh` atualizado para implantar bridge quando middleware estiver saudável e `SRE_ENABLE_BRIDGE` não for `0`. Checkpoint versiona também arquivos de código da bridge.
- **PENDENTE de validação na sessão Kubernetes:** `git pull --ff-only origin main`, `bash sre-killercoda-lab/labs/restore-payment-bridge.sh` e `bash sre-killercoda-lab/labs/test-bridge.sh`.
- Sem garantia de exatamente uma entrega: em falhas pode haver duplicação; produção exige idempotência, DLQ, persistência, TLS, segurança e contratos.

## Checkpoint de integração — 07/11/2026 20:59 UTC
- Usuário executou `bash sre-killercoda-lab/labs/restore-payment-bridge.sh` com sucesso; Deployment `payment-bridge` completou rollout.
- `test-bridge.sh` publicou `PAG-BRIDGE-20261107T205921Z` em Kafka e obteve log JSON `FORWARDED`: `kafka_partition=0`, `kafka_offset=1`, `rabbit_queue=notificacoes-pagamentos`.
- Confirmado **Kafka -> Python bridge -> RabbitMQ** com publicação confirmada e commit de offset Kafka. **Ainda não foi testado consumo final/ACK**, nem semântica exactly-once.
- Preparado novo `notification-worker` Python com ACK manual após simular processamento, logs estruturados e readiness baseada em conexão RabbitMQ. Manifesto e scripts recuperáveis via `iniciar.sh`.
- **Próximo teste pendente no cluster**:
  ```bash
  cd ~/sre-killercoda-lab
  git pull --rebase origin main
  bash sre-killercoda-lab/labs/restore-notification-worker.sh
  bash sre-killercoda-lab/labs/test-notification-worker.sh
  ```
- Validação esperada: log `FORWARDED` na bridge e log `ACK` no worker para **mesmo ID**. Duplicatas ainda possíveis; storage RabbitMQ/Kafka efêmero; laboratório sem dados reais nem Dynatrace ativo.

## Validação ponta a ponta e próximo experimento — 07/11/2026 21:05 UTC
- O usuário executou `restore-notification-worker.sh`: `notification-worker` fez rollout com sucesso e logou `WORKER_READY`.
- Ao iniciar, o worker consumiu e confirmou com `ACK` as notificações previamente acumuladas: `PAG-LAB-20261107T205423Z` e `PAG-BRIDGE-20261107T205921Z`.
- `test-notification-worker.sh`: evento de teste `PAG-WORKER-20261107T210512-25693` publicado no Kafka; bridge logou `FORWARDED` em partição 0, offset 2, fila `notificacoes-pagamentos`; worker logou `ACK` para o **mesmo pagamento_id**. **Fluxo completo Kafka → bridge → RabbitMQ → worker validado por logs correlacionados.**
- Exercício seguinte publicado no GitHub em `labs/test-resilience-worker.sh`: reduzir somente o worker a 0, publicar evento fictício, verificar acumulação/encaminhamento, restaurar worker e aguardar ACK. Contém trap para tentar restaurar a réplica também ao sair por erro. **Ainda NÃO foi executado**.
- A arquitetura é *at-least-once*, com possibilidade de duplicatas e perda de dados quando o Pod do broker é substituído (Kafka/RabbitMQ usam `emptyDir`). Não é um sistema de pagamentos real; posteriormente abordar idempotência, DLQ, métricas e Dynatrace.

## Resiliência testada — 07/11/2026 21:08 UTC
- `bash sre-killercoda-lab/labs/test-resilience-worker.sh` **SUCESSO**.
- Parada controlada do `notification-worker` para 0 réplicas, com Kafka, payment-bridge e RabbitMQ operacionais.
- Mensagem fictícia `PAG-RESILIENCIA-20261107T210854-10902` foi publicada e a Bridge confirmou `FORWARDED` na partição Kafka 0, offset 3.
- Na fila `notificacoes-pagamentos` com Worker parado: `messages_ready=1`, `messages_unacknowledged=0`.
- Após escalar Worker de volta a 1 réplica, rollout teve sucesso e o Worker registrou `ACK` com o mesmo `pagamento_id`.
- Na fila após recuperação: `messages_ready=0`, `messages_unacknowledged=0`.
- Conclusão válida: a fila reteve a notificação durante a interrupção do consumidor e o consumo foi retomado após reinicialização; **não foi testada queda do broker, perda de persistência, nem mecanismo automático de autoscaling**.
- Próxima aula: `labs/test-duplicatas.sh` publica exatamente duas mensagens de teste com `pagamento_id` igual, verifica dois `FORWARDED` e dois `ACK` e demonstra a ausência atual de deduplicação. **Script publicado, não executado ainda**.

## Duplicidade comprovada — 07/11/2026 21:11 UTC
- Script `test-duplicatas.sh` executado pelo usuário com sucesso. ID fictício `PAG-DUPLICADO-20261107T211130-9568`.
- A bridge registrou **2 publicações** no RabbitMQ, Worker fez **2 ACKs** e **2 logs de NOTIFICATION_PROCESSED** para o mesmo ID: falta de idempotência reproduzida.
- Na sequência, foi preparada correção **ainda não validada no cluster**: Worker registra pagamento_id em SQLite (`INSERT OR IGNORE` transacional), ACK para duplicatas sem repetir `NOTIFICATION_PROCESSED`.
- `notification-worker-data`: PVC de 64Mi em `labs/notification-worker.yaml`. Para o lab, somente uma réplica do Worker; PVC protege a tabela em reinício do Pod enquanto a infraestrutura e o volume existirem, não quando toda a VM KillerCoda for destruída.
- RabbitMQ: `restore-notification-worker.sh` instala política de dead-letter que roteia rejeições da fila `notificacoes-pagamentos` para `notificacoes-pagamentos-dlq` pela exchange padrão; worker declara a fila DLQ durável no início.
- Próximos testes **pendentes de execução**, após `git pull --rebase origin main`:
  ```bash
  bash sre-killercoda-lab/labs/restore-notification-worker.sh
  bash sre-killercoda-lab/labs/test-idempotencia.sh
  bash sre-killercoda-lab/labs/test-dlq.sh
  ```
- Critério idempotência: 2 FORWARDED, 2 ACK, **1 NOTIFICATION_PROCESSED, 1 DUPLICATE_SKIPPED** para mesmo ID. Critério DLQ: fila aumenta após publicação de payload sem `pagamento_id`.
- Limites: não oferece exactly-once transacional entre Kafka, RabbitMQ e efeitos externos; não há resiliência dos brokers `emptyDir`, TLS ou real capacidade de produção. Script antigo `test-duplicatas.sh` passa a ser **baseline histórica**, pois espera dois processamentos e deverá falhar após idempotência ativada.

## Idempotência e DLQ validadas — 07/11/2026 21:17 UTC
- PVC `notification-worker-data` criado e **Bound**, tamanho 64Mi, storageClass local-path.
- Worker mostrou `DB_READY` com banco `/data/processed.sqlite3` e `WORKER_READY`.
- `test-idempotencia.sh` para `PAG-IDEMP-20261107T211714-7627`: **FORWARDED=2, ACK=2, PROCESSED=1, DUPLICATE_SKIPPED=1**; dois eventos entregues, apenas um processamento simulado.
- `test-dlq.sh` enviou evento fictício inválido sem `pagamento_id` e a fila `notificacoes-pagamentos-dlq` passou de **0 para 1** mensagem. Teste da política de dead-letter concluído.
- Nova instrumentação publicada, **ainda NÃO validada no cluster**: `apps/notification-worker/metrics_server.py` expõe contadores Prometheus em `/metrics` porta 9100: `sre_notification_processed_total`, `duplicate_skipped_total`, `invalid_total`, `ack_total`, `db_error_total`, `reconnect_total`. Contadores são **por processo e reiniciam a cada restart**; não possuem ID do pagamento como label.
- `labs/notification-worker.yaml` expõe Service interno `notification-worker-metrics:9100`. `restore-notification-worker.sh` inclui `metrics_server.py` no ConfigMap e reinicia o Worker. `checkpoint.sh` inclui este arquivo.
- **Próxima ação pendente no KillerCoda**:
  ```bash
  cd ~/sre-killercoda-lab
  git pull --rebase origin main
  bash sre-killercoda-lab/labs/restore-notification-worker.sh
  bash sre-killercoda-lab/labs/test-metrics.sh
  ```
- Recursos limitados: coletar `/metrics` antes de instalar Prometheus/Grafana completos, OpenTelemetry Collector ou Dynatrace. Este cenário não possui monitoramento Dynatrace ativo nem oferece persistência da VM KillerCoda.

## Métricas Prometheus verificadas — 07/11/2026 21:20 UTC
- O usuário aplicou o novo `notification-worker` com `metrics_server.py`, reiniciou o Deployment e validou rollout completo.
- Logs mostram `METRICS_READY :9100/metrics`, `DB_READY /data/processed.sqlite3` e `WORKER_READY`.
- Scrape `kubectl exec ... python urllib.request` retornou endpoint Prometheus `200` com métricas `sre_notification_processed_total`, `duplicate_skipped_total`, `invalid_total`, `ack_total`, `db_error_total`, `reconnect_total` e `start_time_seconds`. Todos os contadores foram 0 imediatamente após restart, comportamento esperado.
- Service `notification-worker-metrics` criado como ClusterIP, porta 9100. PVC `notification-worker-data` segue Bound com 64Mi, `local-path`.
- **PENDENTE**: validar incremento dos counters após transações fictícias e exposição pelo Service interno. Script `labs/test-metrics-live.sh` publicado para testar idempotência, DLQ e aumento das métricas. Executar `git pull --rebase origin main; bash sre-killercoda-lab/labs/test-metrics-live.sh`. Não foi executado ainda.
- Sem stack Prometheus/Grafana instalada; não instalar Dynatrace pesado sem checar capacidade.

## Checkpoint da sessão — 2026-11-07 21:25:22 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   2d10h   v1.37.1
node01         Ready    <none>          2d9h    v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           28s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           28s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           28s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-9gzww   1/1     Running   0          28s   192.168.1.249   node01         <none>           <none>
pod/drain-demo-89554557b-sth9f   1/1     Running   0          28s   192.168.0.35    controlplane   <none>           <none>
pod/web-blue-5c57468c74-f9b5s    1/1     Running   0          28s   192.168.1.189   node01         <none>           <none>
pod/web-blue-5c57468c74-wbmpx    1/1     Running   0          28s   192.168.0.233   controlplane   <none>           <none>
pod/web-green-6654db8d7b-sb2x9   1/1     Running   0          28s   192.168.1.64    node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.99.195.151    <none>        80/TCP    28s   app=drain-demo
service/sre-web         ClusterIP   10.108.29.249    <none>        80/TCP    28s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.108.176.214   <none>        80/TCP    28s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                     AGE
drain-demo-fmc8p      IPv4          8080    192.168.0.35,192.168.1.249    28s
sre-web-9rjdg         IPv4          8080    192.168.0.233,192.168.1.189   28s
sre-web-green-9t59s   IPv4          8080    192.168.1.64                  28s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Métricas dinâmicas validadas — 07/11/2026 21:27 UTC
- Usuário executou `bash sre-killercoda-lab/labs/test-metrics-live.sh` com sucesso.
- Scrape antes: `processed=0 duplicate=0 ack=0 invalid=0`; após teste com idempotência e DLQ: **processed=1 duplicate=1 ack=2 invalid=1**.
- ID fictício `PAG-IDEMP-20261107T212727-21325`: `FORWARDED=2 ACK=2 PROCESSED=1 DUPLICATE_SKIPPED=1`.
- Mensagem inválida `INVALIDO-20261107T212738-29640` encaminhada para DLQ; filas `notificacoes-pagamentos-dlq` aumentaram de 0 para 1.
- `http://notification-worker-metrics:9100/metrics` validado por requisição interna via Pod `payment-bridge`.
- **Implementado e publicado, ainda não executado**: `labs/check-sre-alerts.sh`, checagem manual leve de replicas Ready, scrape dos contadores e filas RabbitMQ; retorna 0 OK / 1 WARNING / 2 CRITICAL. Como há 1 mensagem intencional na DLQ, o teste deve sinalizar WARNING até sua análise. Não substitui monitoramento contínuo ou alertas reais.
- Próxima ação: `git pull --rebase origin main` e `bash sre-killercoda-lab/labs/check-sre-alerts.sh`. Depois projetar SLI/SLO e observabilidade durável em ambiente com recursos adequados.

## Check SRE e WARNING DLQ — 07/11/2026, após testes de métricas
- Saída validada de `labs/check-sre-alerts.sh`: Kafka, RabbitMQ, payment-bridge e notification-worker **1/1 Ready**.
- Contadores observados: `processed=1`, `duplicate_skipped=1`, `invalid=1`, `ack=2`, `db_error=0`, `reconnect=0`.
- Filas RabbitMQ: `notificacoes-pagamentos` pronta=0, unacked=0; `notificacoes-pagamentos-dlq` pronta=1, unacked=0.
- Veredito do script: **WARNING: revisar filas e mensagens pendentes**. Aviso correto, devido à notificação inválida da aula anterior ainda retida na DLQ. Evidência mantida; não apagar automaticamente.
- Próxima aula publicada no GitHub: `labs/test-sli-slo.sh`. Executa 20 consultas HTTP ao Apache e 20 ao Service /metrics do Worker a partir da bridge e calcula taxa de sucesso/p50/p95 da amostra. **Ainda não foi executado no cluster**.
- Limitação: snapshot com 20 amostras não comprova SLO de disponibilidade mensal 99,9%, nem observa latências dos usuários reais ou tendências ao longo do tempo.

## SLI sintético concluído — 07/11/2026 21:xx UTC
- Usuário executou `labs/test-sli-slo.sh` após atualizar repositório; Apache e Worker saudáveis.
- 20/20 HTTP OK no Apache (`availability_sample_percent=100.0`, p50=5.1ms, p95=8.8ms, 0 falhas).
- 20/20 HTTP OK em `notification-worker-metrics:9100/metrics` (`availability_sample_percent=100.0`, p50=5.4ms, p95=7.1ms, 0 falhas).
- São medições **sintéticas internas no cluster**, não comportamento de clientes externos, nem comprovação de SLO de 99,9% por 30 dias.
- Exercício publicado mas ainda **não executado no KillerCoda**: `labs/test-error-budget.sh`; permite comparar proporção de falhas em uma amostra contra meta de SLO de requisições, e calcular budget equivalente em tempo (uma métrica diferente). Exemplos: `bash sre-killercoda-lab/labs/test-error-budget.sh 40 0` e `bash sre-killercoda-lab/labs/test-error-budget.sh 10000 15`.
- Próximos passos: validar script, preparar coleta persistente e alertas de burn-rate com janelas temporais; Dynatrace ainda sem acesso/tokens configurados.

## Exercício Error Budget validado — 07/11/2026 (saída fornecida no terminal)
- Script `labs/test-error-budget.sh 40 0`: 40 requisições, 0 falhas, SLI da **amostra** 100%, budget proporcional 0,040 falhas, burn rate 0x.
- Script `labs/test-error-budget.sh 10000 15`: 10.000 requisições, 15 falhas, SLI da **amostra** 99,85%, budget proporcional 10 falhas, burn rate 1,5x; cenário acima do budget proporcional em 5 falhas, sem evidência de violação de um SLO real de 30 dias.
- Para uma meta **baseada em tempo** de 99,9% em 30 dias, referência equivalente é 43min12s de indisponibilidade; é uma medida alternativa, não intercambiável com o SLI por requisições.
- Publicado `labs/test-multiwindow-burn-rate.sh` para simular três cenários de alertas multiwindow seguindo o Google SRE Workbook: PAGE_FAST 14,4x simultaneamente em 1h e 5m; PAGE_SUSTAINED 6x em 6h e 30m. **Script novo ainda não executado no KillerCoda**. Os números são amostras FICTÍCIAS, não capturas de histórico do cluster.
- Próximo comando: `git pull --rebase origin main; bash sre-killercoda-lab/labs/test-multiwindow-burn-rate.sh`.
- Referência de projeto: https://sre.google/workbook/alerting-on-slos/ . Regras operacionais reais exigem coleta contínua e definições corretas do que constitui uma falha do usuário.

## Multiwindow burn-rate simulado validado — 07/11/2026
- `test-multiwindow-burn-rate.sh` executado e validado com **3 cenários**.
- Cenário saudável: burn 0x em todas as janelas; sem page.
- Falha aguda: burn 16x (1h), 20x (5m), 3x (6h), 18x (30m); **PAGE_FAST** disparou, `PAGE_SUSTAINED` não.
- Falha sustentada: burn 7x (1h), 8x (5m), 8x (6h), 8x (30m); **PAGE_SUSTAINED** disparou, `PAGE_FAST` não.
- **SIMULAÇÕES**, não decisões baseadas em métricas coletadas em 1h/6h reais.

## Coleta histórica sintética — preparada, pendente de validação
- Publicado `apps/observability/collector.py`: verifica Apache HTTP e Service `/metrics` internamente a cada 30 segundos; registra sucesso, latência e erro em SQLite.
- Adicionados `labs/sre-observer.yaml`, `labs/restore-sre-observer.sh`, `labs/report-sre-observer.sh`: Deployment único leve e PVC de 64Mi `sre-observer-data`. Bootstrap `iniciar.sh` passou a restaurar observador por padrão após Worker; desativável via `SRE_ENABLE_OBSERVER=0`. Backup Git inclui código, mas não contém DB.
- Próximo teste **ainda não executado no cluster**: `git pull --rebase origin main; bash sre-killercoda-lab/labs/restore-sre-observer.sh; bash sre-killercoda-lab/labs/report-sre-observer.sh 5`.
- Nos primeiros minutos, `history_sufficient_for_window=false` é esperado; aguarde coletas suficientes para cobertura. Observações são internas: queda total do cluster não pode ser detectada por um coletor dentro do próprio cluster.
- Limitações: PVC local-path só persiste enquanto VM/nó/storage durar; histórico não sobrevive à expiração do KillerCoda; SLO por requisições reais e alertas de burn-rate real continuam pendentes; Dynatrace não instalado.

## Primeira implantação do observador histórico — 07/11/2026 21:44 UTC
- Usuário executou `labs/restore-sre-observer.sh`: ConfigMap criado, PVC `sre-observer-data` **Bound** (64Mi, local-path), `deployment/sre-observer` com **rollout concluído**.
- Imediatamente após o rollout, `labs/report-sre-observer.sh 5` retornou zero amostras para `apache_http` e `notification_metrics`; disponibilidade, P50/P95 e burn rate vieram nulos, `history_sufficient_for_window=false`. **Não inferir falha** sem verificar logs, pois relatório foi gerado ~4s após PVC criado.
- Próximo diagnóstico pendente: `kubectl -n sre-middleware-lab get pods -l app=sre-observer`; `kubectl -n sre-middleware-lab logs deploy/sre-observer --tail=30`; `kubectl -n sre-middleware-lab exec deploy/sre-observer -- python /app/collector.py once`; `bash sre-killercoda-lab/labs/report-sre-observer.sh 5`.
- Para validar uma janela de 5min com cobertura adequada, coletar por aproximadamente >=4min30; o relatório indica cobertura real. Nada disso representa um SLO externo mensal.

## Histórico observado validado — 07/11/2026 21:45 UTC
- `sre-observer` estava **1/1 Running, 0 restarts**, coletando a cada 30s e gravando no SQLite (`/data/observations.sqlite3`).
- Logs: `SRE_OBSERVER_READY`, seguidos por `SYNTHETIC_SAMPLE` com `success=1` para `apache_http` e `notification_metrics`.
- Após uma coleta manual, `report-sre-observer.sh 5` retornou 5/5 sucessos para cada serviço; cobertura observada de 96 segundos, `history_sufficient_for_window=false`.
- Apache: P50=3,29ms, P95=142,59ms; métricas Worker: P50=2,22ms, P95=56,90ms. Burn rate da amostra 0x para ambos. Percentis muito sensíveis a outliers com somente 5 amostras.
- **Nova aula publicada, ainda não executada**: `labs/test-observer-incident.sh` reduz **somente Apache** a zero replicas, coleta falha sintética, restaura Apache, coleta sucesso e apresenta histórico. Script tenta restaurar Apache em caso de erro. Não usar em produção.
- Próximos comandos: `git pull --rebase origin main` e `bash sre-killercoda-lab/labs/test-observer-incident.sh`. O objetivo é validar registro da indisponibilidade, não um SLO mensal.

## Incidente sintético Apache com recuperação confirmada — 07/11/2026 21:48 UTC
- `labs/test-observer-incident.sh` executado pelo usuário: Apache reduzido para 0 réplicas, observador registrou `success=0` e erro `No route to host`; após restaurar para 1 réplica, novo scrape `success=1`, latência 103,87 ms.
- `notification_metrics` continuou com sucesso ao longo do teste, confirmando que a indisponibilidade foi restrita ao Apache nessa observação.
- Relatório histórico de 5 minutos após incidente: Apache **13 amostras, 11 sucessos, 2 falhas, disponibilidade amostral 84,615%, P50 3,44ms, P95 142,59ms, burn amostral 153,85x**.
- Endpoint `notification_metrics`: **13 amostras, 13 sucessos, 0 falhas, 100% de sucesso, P50 2,22ms, P95 56,90ms, burn 0x**.
- Cobertura da janela: 276 segundos, `history_sufficient_for_window=true` conforme critério didático de 90% do período. É um histórico de **probes internos**, não SLI de usuários, nem prova de infra disponível durante queda completa do cluster.
- Novo script **publicado mas ainda não executado**: `labs/check-observed-burn-rate.sh` calcula burn de 5min/1h/30min/6h usando amostras armazenadas em SQLite, exige cobertura temporal e volume mínimo por janela e devolve `INSUFFICIENT_HISTORY_FOR_PAGING` quando falta histórico de janelas longas. Não envia paging.
- Próxima execução: `git pull --rebase origin main` e `bash sre-killercoda-lab/labs/check-observed-burn-rate.sh`; verificar cobertura antes de inferir alerta.

## Nova trilha publicada — Infraestrutura Sênior Híbrida (10/11/2026)
- Fonte: duas imagens da vaga **Analista de Infraestrutura Sênior — Hidrovias do Brasil**.
- Escopo incorporado ao curso: on-prem/cloud, Azure/AWS/GCP, Hyper-V/VMware, SAN/NAS/backup, redes/VPN/VLAN/firewall/LB, IaC (Terraform/Ansible/ARM/CloudFormation), PowerShell/Bash/Python, monitoração/observabilidade, compliance, FinOps e migração.
- Publicados os documentos `docs/TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md`, `docs/ENTREVISTA-INFRA-SENIOR.md` e `labs/infra-senior/README.md`.
- Publicado **novo código opcional, ainda não testado no cluster**: `labs/infra-senior/audit-k8s.py` (read-only, report de Deployments/nodes/PVC/rede/requests e limites) e `labs/infra-senior/inventario-windows.ps1` (read-only em Windows autorizado; não executa no KillerCoda Linux).
- Esses scripts são manuais e não foram adicionados à restauração automática para preservar recursos. Nenhuma conta cloud, storage remoto, VMware, Dynatrace ou ferramenta IaC adicional foi provisionada.
- Próxima sessão: restaurar o cluster com `bash iniciar.sh`, conferir Pods, executar primeiro `bash sre-killercoda-lab/labs/check-observed-burn-rate.sh` (ainda pendente da aula anterior) e depois `python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py`.
- Comunicação: começar com respostas orais de 15-30 segundos (contexto, ação, evidência) e não confundir provas de conceito com histórico de produção.

## Checkpoint da sessão — 2026-11-11 11:30:42 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   6d      v1.37.1
node01         Ready    <none>          5d23h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           32s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           32s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           32s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-hzzsw   1/1     Running   0          32s   192.168.1.139   node01         <none>           <none>
pod/drain-demo-89554557b-xt8nj   1/1     Running   0          31s   192.168.0.169   controlplane   <none>           <none>
pod/web-blue-5c57468c74-98td8    1/1     Running   0          32s   192.168.1.198   node01         <none>           <none>
pod/web-blue-5c57468c74-ctjbg    1/1     Running   0          32s   192.168.0.225   controlplane   <none>           <none>
pod/web-green-6654db8d7b-k6df8   1/1     Running   0          32s   192.168.1.225   node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.105.164.87    <none>        80/TCP    32s   app=drain-demo
service/sre-web         ClusterIP   10.110.164.200   <none>        80/TCP    32s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.101.110.93    <none>        80/TCP    32s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                     AGE
drain-demo-m2mql      IPv4          8080    192.168.1.139,192.168.0.169   31s
sre-web-green-8whx6   IPv4          8080    192.168.1.225                 32s
sre-web-xzsw4         IPv4          8080    192.168.1.198,192.168.0.225   32s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Restauração KillerCoda e teste end-to-end — 11/11/2026
- Ambiente restaurado de `git clone` e `bash iniciar.sh` no Kubernetes `v1.37.1`, nós `controlplane` e `node01` Ready. O primeiro bootstrap foi interrompido por erro externo de espelho Mozilla no `apt-get update`, antes do deploy; após o ajuste de instalação, a restauração foi concluída no cluster.
- `kubectl -n sre-middleware-lab get pods -o wide` registrou seis Pods `1/1 Running`, `RESTARTS=0`: Apache, Kafka, RabbitMQ e Payment Bridge no `node01`; Notification Worker e SRE Observer em `controlplane`.
- `bash sre-killercoda-lab/labs/test-notification-worker.sh` **passou no novo cluster**; ID fictício `PAG-WORKER-20261111T113533-25778`; evento `FORWARDED` via Kafka partição 0 offset 0 para `notificacoes-pagamentos`, seguido por `ACK` do Worker para o mesmo ID.
- Evidência comprova roteamento e ACK do fluxo Kafka → Bridge → RabbitMQ → Worker nesta sessão, mas não revalida por si só idempotência, DLQ, resiliência ou SLO mensal.
- **Próximo passo ainda pendente**: executar `bash sre-killercoda-lab/labs/check-observed-burn-rate.sh`; as janelas de 1h e 6h estarão insuficientes em sessão recente. Depois: `python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py` para o módulo de Infraestrutura Sênior.

## Burn rate observado validado — 11/11/2026 (nova sessão KillerCoda)
- O teste de fluxo `bash sre-killercoda-lab/labs/test-notification-worker.sh` foi aprovado novamente com pagamento **fictício** `PAG-WORKER-20261111T113533-25778`: Bridge `FORWARDED` Kafka partição 0, offset 0; Worker confirmou `ACK` para mesmo ID. Não demonstra efeitos externos nem transações financeiras reais.
- Após `git pull --rebase origin main`, `bash sre-killercoda-lab/labs/check-observed-burn-rate.sh` executado com sucesso; `deployment/sre-observer` fez rollout/status com sucesso.
- Tanto `apache_http` quanto `notification_metrics`: **10 amostras em 5min, 0 falhas, 270s de cobertura, última amostra com 16s, burn rate 0x; window_covered=true**.
- Janelas `30m`, `1h` e `6h` têm apenas 10 amostras e 270s de cobertura, portanto `window_covered=false`.
- Regras `PAGE_FAST` e `PAGE_SUSTAINED` ficaram **não avaliadas** (não confundindo com alerta validamente não disparado); veredito **INSUFFICIENT_HISTORY_FOR_PAGING**. Esse resultado é correto para um laboratório recém-reconstruído e impede decisões baseadas em dados incompletos.
- Monitoração de endpoints internos; não representa SLO externo/usuários reais nem detecção de queda completa do cluster. Não houve acionamento remoto de paging.
- Próxima atividade **ainda não executada**: `python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py` — inventário read-only de nós, deployments, Pods, PVCs, NetworkPolicies e reservas de CPU/memória. Interpretar requests/limits como declaração, não consumo medido.

## Diagnóstico de infraestrutura sênior — Kubernetes — 11/11/2026
- Usuário executou com sucesso `python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py` no novo KillerCoda.
- Inventário: **2 nodes, 23 pods, 12 deployments, 10 services, 2 PVCs Bound, 0 objetos NetworkPolicy padrão**. 23 Pods em fase Running; nenhum Deployment com menos réplicas Ready do que solicitado.
- `controlplane`: 14 Pods; CPU requests 295m/1000m (29,5%), memória requests 328/2146Mi (15,3%); soma de limites memória 852Mi.
- `node01`: 9 Pods; CPU requests 400m/1000m (40%), memória requests 856/1803Mi (47,5%); soma de limites memória 2656Mi, cerca de **147,3%** da memória allocatable. Isso indica overcommit de *limites*, NÃO uso real >capacidade nem OOM comprovado.
- Lacunas no cluster: **4 containers** com requests CPU/mem incompletos; **10 containers** sem limite de memória. É necessário identificar se pertencem a aplicações de laboratório ou componentes de plataforma antes de alterar algo.
- NetworkPolicies Kubernetes padrão zero; falta de recursos NetworkPolicy por si só não comprova ausência de CiliumNetworkPolicy/controles externos. Nenhuma alteração de configuração realizada.
- **Publicado, pendente de execução**: `labs/infra-senior/diagnostico-recursos.py` detalha por Pod/container as lacunas e tenta consultar `kubectl top` para verificar consumo real, tratando ausência de Metrics Server. Próximo: `git pull --rebase origin main` e `python3 sre-killercoda-lab/labs/infra-senior/diagnostico-recursos.py`.
- Treino oral: "Inventariei a saúde do cluster e comparei requests com capacidade alocável. Identifiquei overcommit de limites no node01 e configurações incompletas. Antes de recomendar ajustes, verificaria uso real e impacto por workload." Sem confundir requests com consumo.


## Novo módulo de vagas — ASR/DR + Infraestrutura híbrida Microsoft — 11/11/2026

- Usuário forneceu requisitos completos para **Azure Site Recovery, Azure Backup, Recovery Services vault, replicação A2A e on-prem VMware/Hyper-V/físicos, Recovery Plans, Test/Planned/Unplanned Failover, Failback, RPO/RTO, Azure Monitor/Log Analytics, VPN/ExpressRoute, Storage/Entra/RBAC, automação Azure CLI/PowerShell, ITIL4 e documentação DR**.
- Reforçou demandas por Terraform, provisionamento, CI/CD, troubleshooting, monitoramento e trabalho multidisciplinar.
- Incluiu Windows 10/11, Server 2016/2019/2022, AD DS/GPO/DNS/DHCP/File Server, Entra Connect/Cloud Sync, Microsoft 365, MFA/Conditional Access/Zero Trust, VMware/Proxmox, suporte Azure e AWS.
- Publicados **SEM execução no cluster**: `labs/dr-azure/simular-dr.py` (3 cenários simulados, RPO/RTO, plano de recovery, failback com reconciliação), `labs/dr-azure/inventario-azure-readonly.sh` (opcional Azure CLI e conta autorizada), `labs/dr-azure/README.md`, `docs/TRILHA-DR-ASR-AD-M365-DEVOPS.md`.
- Os scripts não replicam VMs, não acessam cloud automaticamente, não fazem failover real e não foram testados pelo usuário. O Azure Site Recovery continua como tópico **a implementar na assinatura sandbox autorizada**.
- Próxima aula: `git pull --rebase origin main` e `python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py`. Revisar os resultados planejado vs não planejado e explicar RPO/RTO; depois estudar Azure Backup e recovery plans reais com referências Microsoft.
- A auditoria adicional `labs/infra-senior/diagnostico-recursos.py` da aula de capacidade permanece pendente de execução, podendo ser retomada em seguida.

## Checkpoint da sessão — 2026-11-12 22:07:38 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   7d10h   v1.37.1
node01         Ready    <none>          7d10h   v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           19s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           19s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           19s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE   IP              NODE           NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-khbgb   1/1     Running   0          18s   192.168.0.68    controlplane   <none>           <none>
pod/drain-demo-89554557b-lnndt   1/1     Running   0          18s   192.168.1.40    node01         <none>           <none>
pod/web-blue-5c57468c74-l8ggz    1/1     Running   0          19s   192.168.0.97    controlplane   <none>           <none>
pod/web-blue-5c57468c74-rmgnn    1/1     Running   0          19s   192.168.1.240   node01         <none>           <none>
pod/web-green-6654db8d7b-h2ljw   1/1     Running   0          19s   192.168.1.18    node01         <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.98.252.15     <none>        80/TCP    18s   app=drain-demo
service/sre-web         ClusterIP   10.102.100.166   <none>        80/TCP    19s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.106.117.57    <none>        80/TCP    19s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-9slhs      IPv4          8080    192.168.0.68,192.168.1.40    19s
sre-web-4zfm7         IPv4          8080    192.168.0.97,192.168.1.240   20s
sre-web-green-j6nb7   IPv4          8080    192.168.1.18                 20s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## INC-SRE-001 — Investigação de latência HTTP (12/11/2026)

**Cenário controlado de laboratório, não incidente real de produção.**

- `sre-release-lab`: dois Pods `drain-demo` 1/1 Running (sem restart), Service `drain-demo` ClusterIP 10.98.252.15:80; Pods `web-blue` e `web-green` também Running.
- Teste por `kubectl exec deploy/web-blue`: `GET /ready` retornou `READY` em **0,127 s**, enquanto `GET /slow` retornou `COMPLETED pod=drain-demo-89554557b-khbgb` em **12,163 s** (tempos de comando incluem overhead do kubectl).
- Logs do Pod `drain-demo-89554557b-khbgb`: `REQUEST_START 1794521476.381474` e `REQUEST_END 1794521488.382077`, diferença **12,000603 s**. `GET /slow HTTP/1.1` retornou **200**.
- No período, probes `GET /ready` continuaram retornando **HTTP 200**, inclusive durante o processamento da requisição lenta. O outro Pod registrou readiness 200.
- `kubectl get cm drain-app -o jsonpath='{.data.server\.py}'` comprovou que o handler `/slow` executa `time.sleep(12)` antes de enviar `HTTP 200`. **Causa do atraso reproduzido confirmada: espera intencional de aplicação**. Não se demonstrou saturação de CPU/memória, falha de rede nem degradação generalizada.
- **Decisão SRE:** não reiniciar Pods, nem aumentar recursos sem evidência. Alertas de disponibilidade (`/ready`) e de latência em endpoints de negócio devem ser distintos; não interpretar resposta 200 como desempenho satisfatório. Cuidado para não fazer o endpoint artificial `/slow` definir o SLO de usuários reais.
- Próxima aula: investigar um **novo** incidente controlado com contenção de CPU ou dependência lenta, coletar antes/durante/depois e validar mitigação. Não confundir o caso `/slow` com lentidão inesperada em produção.

**Fala curta para entrevista:** "Em um cenário de lentidão, comparei health check e operação específica, medi os tempos, correlacionei logs e ConfigMap. Encontrei um atraso de 12 segundos introduzido pela aplicação, sem evidência de problema de infraestrutura. Evitei reinícios desnecessários e separei disponibilidade de latência."


## Novo módulo criado — PostgreSQL, Backend e Frontend — 12/11/2026

- Solicitação: acrescentar PostgreSQL para testes reais de integração backend/frontend e troubleshooting SRE de latência, depois de confirmar que o incidente /slow anterior era causado por sleep intencional.
- Publicado no repositório, ainda **não executado no KillerCoda**: módulo opcional labs/fullstack-postgres. Componentes: namespace sre-fullstack-lab; StatefulSet PostgreSQL 17-alpine, PVC 1Gi; Secret gerado aleatoriamente no cluster; ConfigMap com schema SQL; API Python 3.12 com Psycopg 3, rotas GET/POST/PATCH e /metrics; frontend HTML/JavaScript servido por Nginx, com proxy /api/; scripts de deploy, validação read-only e teste de escrita.
- Dados persistem no PVC apenas enquanto a infraestrutura KillerCoda existir, sem backup/HA. O bootstrap iniciar.sh não foi alterado, para poupar recursos.
- O teste de fluxo de escrita e leitura criará um **incidente fictício** no banco; o endpoint /api/slow introduz espera controlada de até 3s, não prova contenção real de CPU nem lock de banco.
- **Próxima aula pendente:** em KillerCoda restaurado, executar git pull e bash sre-killercoda-lab/labs/fullstack-postgres/restore-fullstack.sh. Analisar saída de kubectl (pvc/pods/deployments), depois validate-fullstack.sh e test-incident-flow.sh.
- Cuidado: o backend instala dependência Python em startup e exige acesso à PyPI; se não houver, diagnosticar logs. O exemplo não implementa autenticação, TLS, HA ou DR, logo não deve ser exposto publicamente nem utilizado com dados reais.

## Instalação Full Stack validada — 12/11/2026
- Com `git pull --rebase origin main`, foram baixados os 13 arquivos do módulo `sre-killercoda-lab/labs/fullstack-postgres` e executado `restore-fullstack.sh` no KillerCoda.
- Namespace `sre-fullstack-lab` e Secret com senha randômica criados; 4 ConfigMaps publicados.
- `StatefulSet/postgres`, `Deployment/incidents-api` e `Deployment/incidents-web` concluíram rollout. **3/3 Pods 1/1 Running, RESTARTS=0**: `postgres-0` no `controlplane`, API e frontend no `node01`.
- Services ClusterIP: `postgres` TCP 5432, `incidents-api` TCP 8000, `incidents-web` TCP 80. PVC `data-postgres-0` **1Gi, RWO, Bound, local-path**.
- `validate-fullstack.sh` **aprovado**. PostgreSQL `srelab|0` comprova schema/tabela acessíveis e nenhum incidente cadastrado no momento da verificação. `GET http://incidents-web/api/health` retornou `{"status":"ok","database":"connected","test":1}`, e `GET /api/incidents` retornou `{"items":[]}`. Atravessou Nginx/API, com Postgres em outro node.
- Métricas `sre_api_requests_total` retornaram contadores HTTP 200 e `/readyz` com 2 ocorrências HTTP 503 anteriores à coleta, mais 1 resposta 200; **não está comprovado** o motivo dos 503, embora compatível com aquecimento do PostgreSQL. No momento final todos Pods Ready.
- **Ainda pendente:** executar `bash sre-killercoda-lab/labs/fullstack-postgres/test-incident-flow.sh` (POST + PATCH + GET, escrita no DB), validar a UI em preview local do KillerCoda, e fazer os testes de latência/dependência.
- Segurança: aplicação sem autenticação/TLS e com dados fictícios, não expor em rede pública; PVC local-path persiste durante sessão mas não após destruição do KillerCoda.

## Full Stack: CRUD pelo frontend com persistência SQL — 12/11/2026
- PostgreSQL `srelab`, tabela `incidents`: `SELECT id, service, severity, status FROM incidents ORDER BY id DESC` exibiu dois registros **P2/INVESTIGATING**: ID 1 `api-pagamentos-lab` (criado anteriormente pelo teste automatizado) e ID 2 `postgres-api` (registrado pelo usuário no painel web).
- Comprovado que a interface HTTP no KillerCoda (acessada por port-forward 8081), o Nginx, a API Python e o PostgreSQL se comunicam com persistência. Não atribuir a origem da alteração de status INVESTIGATING apenas ao POST, pois o POST padrão cria como OPEN.
- **Próxima aula, ainda não executada:** comparar tempos HTTP `GET /api/health` (verifica banco por SELECT 1) versus `GET /api/slow?ms=2000` (sleep artificial do backend sem consulta SQL) usando perf_counter em cliente Python executado dentro do Pod de API contra `http://incidents-web`. Antes de qualquer ajuste, correlacionar desempenho da camada correta.
- Este teste de latência será diagnóstico educacional, não indica lentidão genuína de PostgreSQL.

## INC-SRE-002 — Latência do backend vs health PostgreSQL — 12/11/2026
- Cliente Python no Pod `deploy/incidents-api` fez HTTP via Service Nginx `incidents-web` e mediu com `time.perf_counter()`.
- `GET /api/health`: HTTP 200, **0,082s** (82ms), executa validação simples `SELECT 1` no PostgreSQL.
- `GET /api/slow?ms=2000`: HTTP 200, **2,003s** (2003ms), simula atraso explícito via `time.sleep(2)` sem consulta a SQL.
- **Diagnóstico:** a demora reproduzida no endpoint /api/slow é intencional na camada backend Python. O teste simples de saúde da base passou; isso não comprova ausência de problemas em consultas reais, locks, throughput ou p95 em tráfego de produção.
- A medição inclui Nginx, rede e HTTP interno, porém somente uma requisição por endpoint; não representa latência geral, SLO ou desempenho sob carga.
- **Decisão:** não reiniciar serviços nem dimensionar CPU/RAM com base nesse teste. Próximo passo: iniciar baseline PostgreSQL **somente leitura**, consultar `pg_stat_activity`, tamanho e contagem da tabela e `EXPLAIN (ANALYZE, BUFFERS) SELECT...` antes de simular contenção real em DB de laboratório.
- Fala de 20s: "Comparei uma operação lenta com o health do banco, medi 2s contra 82ms e correlacionei com o código. Descobri que a latência foi introduzida propositalmente no backend; evitei modificar o banco sem evidência."

## INC-SRE-003 — Baseline PostgreSQL e próximo teste de bloqueio — 12/11/2026

- Usuário executou `pg_stat_activity` em `srelab`. Retornou apenas a própria sessão de diagnóstico `pid=1441, state=active, duration=00:00:00`, com `wait_event_type` e `wait_event` vazios. **Não foram observados bloqueios naquele instante**; não significa que nunca ocorram esperas.
- `EXPLAIN (ANALYZE, BUFFERS)` de `SELECT id, service, severity, status FROM incidents ORDER BY id DESC LIMIT 50`: 2 linhas, Seq Scan, Sort quicksort 25kB, 4 shared buffer hits, planning 1,025 ms, **execution 0,082 ms**. Em tabela de duas linhas, Seq Scan é esperado e eficiente, não justificando novo índice.
- Nenhuma lentidão do PostgreSQL foi confirmada na consulta de baseline; separar esse resultado da simulação de 2s via `/api/slow?ms=2000`.
- Publicado **pendente de execução no cluster**: `labs/fullstack-postgres/test-db-lock.sh`, teste controlado de disputa por row lock em registro fictício, medição de `pg_stat_activity.wait_event_type=Lock`, `pg_blocking_pids`, lock_timeout (3,5s), `ROLLBACK` garantido. Usa Psycopg já instalado no Pod da API; não persiste alterações.
- Próxima aula: `git pull --rebase origin main` e `bash sre-killercoda-lab/labs/fullstack-postgres/test-db-lock.sh`; interpretar concorrência vs saturação de recursos. Não executar fora do namespace lab.

## INC-SRE-003 — Contenção por row lock reproduzida e validada — 12/11/2026
- `git pull --rebase origin main` atualizou o módulo `labs/fullstack-postgres/test-db-lock.sh`; `Deployment/incidents-api` retornou rollout concluído.
- Exercício executado pelo usuário com sucesso em `sre-fullstack-lab` sobre **registro fictício ID 2**. Transação A reteve row lock, enquanto a transação B tentou atualizar o mesmo registro.
- Saída coletada em tempo real: `pid=1781`, `state=active`, `wait_event_type=Lock`, `wait_event=transactionid`, `pg_blocking_pids=[1779]`. Portanto, **PID 1779 foi o bloqueador observado** da sessão 1781.
- A transação B retornou `SQLSTATE 55P03` após `lock_timeout` configurado em **3500 ms** (valor de limite, não medição exata da duração). 
- A transação A liberou o lock via `ROLLBACK`; todas as transações foram revertidas, sem atualização persistida segundo o resultado do script. `wait_seen=True`, `timeout_seen=True`, mensagem final **SUCESSO: bloqueio reproduzido, observado e encerrado com rollback**.
- **RCA do cenário de laboratório:** a demora nesta operação concorrente decorreu da espera por bloqueio de transação PostgreSQL. Este teste isolado não demonstra saturação de CPU, lentidão geral do PostgreSQL nem impacto real no navegador.
- Próxima ação: verificar novamente se as sessões artificiais desapareceram e se o status do incidente 2 permaneceu `INVESTIGATING`. Em uma etapa posterior, correlacionar requisição `PATCH` da API com bloqueio SQL, medir latência HTTP e preparar runbook de mitigação; não executar `pg_terminate_backend` indiscriminadamente em produção.
- **Fala treinável:** "Reproduzi uma espera por bloqueio no PostgreSQL. Usei pg_stat_activity e pg_blocking_pids para identificar o processo bloqueador; o cliente atingiu lock_timeout e confirmei a liberação pelo rollback, sem mudar dados. Isso mostra que latência pode vir de contenção, mesmo sem prova de falta de CPU." 

## Bootstrap unificado: GitHub CLI + Full Stack por padrão; roadmap VirtualBox — 12/11/2026
- Necessidade confirmada pelo usuário: em **toda nova sessão** levantar tudo a partir do GitHub (`bash iniciar.sh`), incluindo PostgreSQL, API, frontend, middleware e GitHub CLI (`gh`), para migração futura a VMs no VirtualBox.
- Verificado: `sre-killercoda-lab/setup.sh` já instala `gh` via `apt-get` quando ausente e solicita autorização GitHub por navegador quando não autenticado. Não reinstala a cada execução na mesma VM. Em sessões descartáveis, reautenticação será necessária.
- Alterado `setup.sh`: agora `SRE_ENABLE_FULLSTACK=1` é o padrão; roda `labs/fullstack-postgres/restore-fullstack.sh` e depois `validate-fullstack.sh` **automaticamente**, antes do middleware; em caso de falha reporta ERRO e retorna código 1 ao fim da inicialização. Não roda `test-incident-flow.sh` automaticamente, evitando inserções duplicadas.
- Mantidos toggles independentes `SRE_ENABLE_MIDDLEWARE=0` (poupa memória) e `SRE_ENABLE_FULLSTACK=0` (pula o banco/frontend).
- Atualizados `README.md`, `sre-killercoda-lab/README.md` e `labs/fullstack-postgres/README.md` para refletir fluxo automático e ensaios já validados.
- Criado `docs/MIGRACAO-VIRTUALBOX.md` com proposta Ubuntu Server + k3s, GitHub CLI, storage persistente, rede isolada, backups `pg_dump` e critérios de restauração. A VM VirtualBox/k3s **não** foi criada nem testada.
- **Ponto crucial:** GitHub guarda arquivos e schema, não dados do PostgreSQL. Em KillerCoda novo o banco será recriado VAZIO; os incidentes antigos não são restaurados sem backup externo. Em VirtualBox, volume durável e backups verificados serão requisitos.
- **Próximo teste pendente:** usuário deve fazer `git pull --rebase origin main` na sessão existente e `bash iniciar.sh` (pode reexecutar recursos sem eliminar Secret/PVC) para confirmar integração automática no runtime. Em nova sessão, `git clone ... && bash iniciar.sh`.


## Novo modulo planejado — DevOps Senior Operacoes GCP (13/11/2026)

- Vaga fornecida pelo usuario com requisitos de L3/War Room P1, GKE/Compute Engine/Cloud Run, IAM/VPC/Cloud Armor, Terraform, GitHub Actions/Cloud Build/ArgoCD, Cloud SQL/Bigtable/PubSub, Cloud Operations/Prometheus/Grafana, FinOps, SLI/SLO, DR, seguranca, Scrum/Kanban, Discovery e mentoria.
- Criado [TRILHA-GCP-DEVOPS-SENIOR-OPERACOES.md](TRILHA-GCP-DEVOPS-SENIOR-OPERACOES.md), plano de 8 semanas com labs, entregaveis, runbooks, SLOs, War Room e distincao entre experiencia profissional e educacional.
- Criado [labs/gcp-sre/README.md](../labs/gcp-sre/README.md) e o script [assessment-local.sh](../labs/gcp-sre/assessment-local.sh), auditoria Kubernetes **somente leitura** com verificacao de ferramentas, nodes, pods, deployments, HPA, PVC, RBAC, capacidade e servicos Full Stack.
- O novo script **ainda nao foi executado pelo usuario**. Primeiro comando: cd ~/sre-killercoda-lab && git pull --rebase origin main && bash sre-killercoda-lab/labs/gcp-sre/assessment-local.sh
- GCP real/GKE/Cloud SQL/Bigtable/Cloud Run e custos permanecem no planejamento; **nenhum recurso Google Cloud criado e nenhuma mudanca no iniciar.sh**. A conta/quotas/billing/limpeza precisam ser alinhadas antes.
- Escopo para notebook de 16GiB: reaproveitar Kubernetes KillerCoda ou Ubuntu K3s VirtualBox. Fazer um assunto de cada vez, sem provisionamento automatico.


## Java Middleware: Apache HTTP Server, Tomcat e WildFly — 13/11/2026

- Usuario solicitou subir o laboratorio no KillerCoda e incluir estudo de quando usar Apache, Tomcat e JBoss. Explicada distincao: Apache HTTP Server = proxy/web; Tomcat = container Servlet/JSP; WildFly = application server comunitario Jakarta EE, **nao e o JBoss EAP comercial**.
- Publicado modulo opt-in em [labs/java-middleware/](../labs/java-middleware/README.md): namespace sre-java-lab; ConfigMaps de uma pagina JSP Java e de mod_proxy Apache; Deployments + ClusterIP Services Apache HTTP Server 2.4 e Tomcat 10.1; startup/readiness/liveness e requests/limits.
- Publicado WildFly EE 10 comunitario com JDK 17 **opcional** via --with-wildfly; nao instalar automaticamente porque o KillerCoda tem capacidade pequena. Sem uso de GCP, sem credenciais, sem administrar software corporativo real.
- Scripts restore-java.sh e validate-java.sh: teste interno HTTP Apache -> Tomcat e, opcionalmente, Apache -> WildFly, com pagina JSP. **Ainda nao executado nem validado pelo usuario no cluster**; nao afirmar sucesso de deploy.
- Proxima execucao: iniciar o lab pelo iniciar.sh (GitHub CLI automatico, PostgreSQL/API/Nginx restaurados). Depois git pull --rebase origin main; bash sre-killercoda-lab/labs/java-middleware/restore-java.sh; bash sre-killercoda-lab/labs/java-middleware/validate-java.sh; salvar resultados. Testar WildFly quando houver memoria.
- Proximas evolucoes: WAR de aplicacao real, monitoramento JVM GC/heap/threads, JNDI/JDBC/datasource para PostgreSQL, logs e prova de 503/timeout com proxy, runbook de RCA.

## Checkpoint da sessão — 2026-11-13 20:39:16 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   8d    v1.37.1
node01         Ready    <none>          8d    v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           20s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           20s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           20s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-84ht5   1/1     Running   0          20s   192.168.1.73    node01   <none>           <none>
pod/drain-demo-89554557b-lpczr   1/1     Running   0          20s   192.168.1.201   node01   <none>           <none>
pod/web-blue-5c57468c74-dm97n    1/1     Running   0          20s   192.168.1.97    node01   <none>           <none>
pod/web-blue-5c57468c74-ns8vn    1/1     Running   0          20s   192.168.1.116   node01   <none>           <none>
pod/web-green-6654db8d7b-kr5w6   1/1     Running   0          20s   192.168.1.142   node01   <none>           <none>

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.97.34.228     <none>        80/TCP    20s   app=drain-demo
service/sre-web         ClusterIP   10.100.53.28     <none>        80/TCP    20s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.106.207.190   <none>        80/TCP    20s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-lg696      IPv4          8080    192.168.1.201,192.168.1.73   20s
sre-web-g2chk         IPv4          8080    192.168.1.97,192.168.1.116   20s
sre-web-green-zjtdb   IPv4          8080    192.168.1.142                20s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.

## Java Middleware — primeiro rollout Apache/Tomcat confirmado (13/11/2026)
- Usuário executou `kubectl get nodes`: `controlplane Ready` e `node01 Ready`, ambos Kubernetes v1.37.1, uptime de oito dias (segundo a saída enviada).
- Em `sre-java-lab`, os Pods `apache-gateway-5f6fcb8697-bbfxp` e `tomcat-app-6ff5f656d8-b66rj` estão `1/1 Running`, `RESTARTS=0`, idade aproximada 3m26s.
- Services encontrados: `apache-gateway` ClusterIP `10.104.156.121:80` e `tomcat-app` ClusterIP `10.106.108.232:8080`. Não gravar endereços dinâmicos como configuração fixa de próxima sessão.
- **Confirmado até agora:** recursos Kubernetes implantados e saudáveis; **ainda não foi enviada a saída do teste funcional HTTP** Apache -> Tomcat -> JSP.
- Próximos comandos: `bash sre-killercoda-lab/labs/java-middleware/validate-java.sh`; após sucesso, `kubectl -n sre-java-lab port-forward --address 0.0.0.0 svc/apache-gateway 8090:80` somente em laboratório isolado, prévia em KillerCoda Traffic/Ports, rota `/tomcat/index.jsp`.
- Somente depois avaliar memória do cluster antes de ativar WildFly opcional; não usar JBoss EAP comercial sem licenciamento.

## Java Middleware — HTTP Apache → Tomcat JSP validado em Kubernetes (13/11/2026)
- Usuário executou `bash sre-killercoda-lab/labs/java-middleware/validate-java.sh` com **sucesso real no KillerCoda**.
- Pods: `apache-gateway-5f6fcb8697-bbfxp` e `tomcat-app-6ff5f656d8-b66rj`, ambos `1/1 Running`, **0 reinícios**; provisionados em `node01` (~5m31s de execução no momento do teste).
- Deployments `apache-gateway` (imagem `httpd:2.4-alpine`) e `tomcat-app` (imagem `tomcat:10.1-jdk17-temurin`) `1/1 READY / AVAILABLE`; Services `apache-gateway:80` e `tomcat-app:8080`.
- Teste HTTP por dentro de `apache-gateway` para `http://127.0.0.1/tomcat/index.jsp` retornou:
  ```text
  SRE Java Middleware Lab
  Servidor: Apache Tomcat/10.1.61
  Status: OK
  Data UTC: 2026-11-13T20:45:59.149345365Z
  ```
- **Comprovado:** proxy reverso Apache HTTP Server → Service Kubernetes → container Tomcat → JSP, sem exposição externa. Resultado funcional da aplicação, não apenas Pod Ready.
- `WILDFLY: nao instalado, teste ignorado.` Não afirmar que o JBoss/WildFly esteja operacional.
- Próximo teste: opcional preview via port-forward 8090 na interface KillerCoda; avaliar capacidade real de nodes e consumo para saber se WildFly opcional cabe sem sobrecarregar; estudar logs JVM, deploy WAR e erros 503.
- Os endereços IP observados são dinâmicos da sessão e não devem ser copiados como configuração persistente.


## Preparacao para WildFly — avaliacao de requests/limits e revisao de imagem (13/11/2026)

- O usuario coletou `kubectl describe nodes | grep -A 8 'Allocated resources:'` para os dois nodes. Saida (sem nomes dos nodes): node do primeiro bloco requests CPU **325m (32%)**, memoria **210Mi (9%)**, limits CPU **100%**, memoria **1364Mi (63%)**; node do segundo bloco requests CPU **445m (44%)**, memoria **570Mi (31%)**, limits CPU **3450m (345%)**, memoria **2848Mi (157%)**.
- **Interpretacao:** limites somados >100% nao significam RAM/CPU atual utilizada, apenas sobrerreserva potencial. Falta medir uso real com `kubectl top nodes` e `kubectl top pods -A --sort-by=memory`, alem de `MemoryPressure`; metricas podem estar indisponiveis se nao houver Metrics Server.
- WildFly configurado com request **512Mi**, limit **1200Mi**, request CPU 200m; a soma de requests sugere que pode ser agendavel num node, mas o risco de OOM/pressao nao esta descartado.
- Ajustado `labs/java-middleware/wildfly.yaml`: imagem EE10 para JDK21 (`quay.io/wildfly/wildfly-ee-10:latest-jdk21`), conforme atualizacao oficial que retirou suporte continuado de JDK17; initContainer agora corrige ownership UID/GID 1000 do volume deploy para permitir arquivo marcador do scanner.
- **Nao foi feito rollout do WildFly ainda.** Decidir apos resultados de consumo e status do node; validar Apache->WildFly->JSP quando seguro e registrar logs/eventos/uso de memoria.

## Preflight WildFly — Metrics API indisponivel, nodes sem MemoryPressure (13/11/2026)
- Usuario executou `kubectl top nodes` e `kubectl top pods -A --sort-by=memory`; ambos responderam `error: Metrics API not available`. Nao afirmar consumo real de RAM/CPU sem telemetria.
- `kubectl get nodes -o wide` mostrou `controlplane` (172.30.1.2) e `node01` (172.30.2.2), ambos `Ready`, Kubernetes v1.37.1, Ubuntu 24.04.5, runtime containerd://2.2.1.
- `kubectl describe nodes | grep -E 'Name:|MemoryPressure'`: **MemoryPressure=False** em controlplane e node01, com `KubeletHasSufficientMemory`; isto indica ausencia de pressao detectada pelo kubelet, nao garante RAM para qualquer workload.
- Perfil WildFly em `labs/java-middleware/wildfly.yaml`: request memoria 512Mi, limite 1200Mi. O node01 tinha soma de limites de memoria ~157% da memoria alocavel, embora requests ~31% na observacao anterior; risco de sobrecompromisso.
- Proximo teste SEM instalar metrics-server: consultar Kubelet Summary API via API server (`kubectl get --raw /api/v1/nodes/NN/proxy/stats/summary`) e verificar `node.memory.workingSetBytes` e `availableBytes`. Esse endpoint pode estar inacessivel por RBAC; se isso ocorrer registrar sem alterar seguranca.
- Somente depois de observar recursos ou revisar risco, testar WildFly opcional manual (`restore-java.sh --with-wildfly`), validar JSP e monitorar Pod events/OOM. Imagem EE10/JDK21 foi confirmada na documentacao oficial do WildFly.

## WildFly — memória observada via Kubelet Summary API (13/11/2026)
- A Kubelet Summary API foi consultada com sucesso via API Server em `/api/v1/nodes/NODE/proxy/stats/summary`, **sem** Metrics Server.
- `controlplane`: `workingSetBytes` equivalente a **1454 MiB**; `availableBytes` equivalente a **792 MiB**.
- `node01`: `workingSetBytes` equivalente a **1096 MiB**; `availableBytes` equivalente a **808 MiB**.
- Estes valores são instantâneos, e a Summary API pode incluir diferença de contabilidade com memória do host e não equivale diretamente à capacidade alocável do scheduler. Não há `MemoryPressure` em ambos segundo inspeção anterior.
- WildFly opcional foi configurado com **request 512Mi**, **limit 1200Mi** de memória. O limite é maior do que a memória disponível estimada **em qualquer um dos nós**. Isto não impede necessariamente o scheduler de colocar o Pod (scheduler usa requests), mas aumenta o risco se a JVM crescer perto do limite.
- **Decisão:** não implantar ainda com perfil atual. Próxima medida: ordenar Pods por `pods[].memory.workingSetBytes` na mesma Summary API para identificar cargas opcionais a pausar ou reduzir. Preservar PostgreSQL/Tomcat e não instalar metrics-server automaticamente.
- Ao liberar RAM e verificar ambiente, avaliar implantação gradual do WildFly e validar Apache -> WildFly -> JSP, com eventos, logs e saúde do node. Nenhuma modificação no cluster foi feita por esta análise.

## WildFly — consumidores de memoria e perfil light publicado (13/11/2026)
- Usuário executou Kubelet Summary API para top10 Pods; no controlplane os maiores foram `kube-apiserver` **334MiB**, Cilium **195MiB**, controller-manager **81MiB**, etcd **53MiB**, operador Cilium **52MiB**. No node01: **Cilium 345MiB**, **Tomcat 120MiB**, Cilium Envoy 58MiB, **API Python 40MiB**, **PostgreSQL 28MiB**, Apache httpd 6MiB; demais workloads modestos.
- Não remover Cilium, kube-apiserver, etcd, CoreDNS e outros componentes essenciais para liberar memória. A capacidade observada via Kubelet foi 792MiB disponíveis no controlplane e 808MiB no node01; snapshot, não reserva garantida.
- Alterado `labs/java-middleware/wildfly.yaml` para perfil **mais restrito**, solicitando `256Mi`, limite `640Mi`, JVM `JAVA_OPTS=-Xms128m -Xmx256m -XX:MaxMetaspaceSize=192m -Djava.awt.headless=true`, mantendo WildFly EE10/JDK21 e sem NodePort/LoadBalancer.
- Em `labs/java-middleware/README.md`, documentado o risco de pouco espaço residual sob consumo máximo e rollback com exclusão apenas de `wildfly.yaml`. **Ainda não foi executado o deploy do WildFly pelo usuário**, portanto não afirmar que funciona.
- Próximo passo no KillerCoda: `git pull --rebase origin main`, `bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly`, monitorar eventos/logs e validar Apache -> WildFly -> JSP, conferir node MemoryPressure e memoria de trabalho. Se falhar, parar apenas WildFly e preservar Tomcat e PostgreSQL.


## INC-SRE-004 — WildFly CrashLoopBackOff causado por CPU sem x86-64-v3 (13/11/2026)

- Usuário confirmou `pwd=/root/sre-killercoda-lab` e `validate-java.sh` presente: erro de `No such file or directory` anterior ocorreu por executar de `/root` em vez da raiz do clone.
- `wildfly-app-b6c85549f-q4w2d` em `node01` ficou `0/1 CrashLoopBackOff`, 5 reinícios; `kubectl get pods -l app=wildfly-app -o jsonpath` evidenciou `LastState.terminated.reason=Error`, `exitCode=127`.
- **Prova da causa raiz:** `kubectl logs deploy/wildfly-app -c wildfly --previous --tail=100` retornou exatamente `Fatal glibc error: CPU does not support x86-64-v3`. A imagem `quay.io/wildfly/wildfly-ee-10:latest-jdk21` usa UBI10 recente, com requisito x86-64-v3 segundo a documentação oficial do WildFly 41/RHEL10. Falha anterior à JVM atender porta 8080, logo probe `connection refused` é efeito secundário.
- InitContainer terminou `Completed / Exit 0` e Apache/Tomcat continuaram `1/1 Running`. Não há indicação de `OOMKilled`. **Não investigar exclusivamente heap/memória como causa.**
- Mitigação recomendada ao usuário: `kubectl -n sre-java-lab scale deployment/wildfly-app --replicas=0` para interromper crash loops sem afetar outros Deployments.
- **Correção permanente nos manifestos do lab (publicada, ainda não validada em runtime):** `wildfly.yaml` agora fixa `quay.io/wildfly/wildfly-ee-10:40.0.1.Final-jdk21` (base UBI9, compatível com CPU inferior a x86-64-v3), mantendo perfil 256Mi request/640Mi limit. `restore-java.sh` faz `kubectl scale deployment/wildfly-app --replicas=1` após aplicar YAML para reativar até se tiver sido escalado para zero.
- Próximos comandos: `cd ~/sre-killercoda-lab && git pull --rebase origin main`; `bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly`; `bash sre-killercoda-lab/labs/java-middleware/validate-java.sh`. Registrar logs, startup, HTTP Apache->WildFly->JSP. Se falhar de novo, logs --previous e pod describe antes de novas mudanças.
- **Atenção:** versão WildFly 40 antiga não recomendada para produção; fallback apenas laboratório isolado. Migração para máquinas com CPU x86-64-v3 e imagens atuais é a correção de arquitetura de longo prazo.

## INC-SRE-004 — Recuperacao validada Apache → WildFly JSP (13/11/2026)
- Usuário confirmou funcionalmente a correção do incidente `CrashLoopBackOff` causado por `Fatal glibc error: CPU does not support x86-64-v3`. A imagem de compatibilidade `quay.io/wildfly/wildfly-ee-10:40.0.1.Final-jdk21` permitiu inicializar no KillerCoda.
- `validate-java.sh` mostrou HTTP de Apache → WildFly → JSP com resposta:
  ```text
  SRE Java Middleware Lab
  Servidor: WildFly 40.0.1.Final (WildFly Core 32.0.2.Final) - 2.4.1.Final
  Status: OK
  Data UTC: 2026-11-13T21:10:15.681415850Z
  VALIDACAO: consultas HTTP realizadas pelo Apache dentro do cluster.
  ```
- Pods em `sre-java-lab` após recuperação: `apache-gateway-5f6fcb8697-bbfxp` **1/1 Running, 0 restarts, 29min**; `tomcat-app-6ff5f656d8-b66rj` **1/1 Running, 0 restarts, 29min**; `wildfly-app-58bcd7bcc-z8nrf` **1/1 Running, 0 restarts, 64s**, todos no `node01`.
- **Confirmado:** HTTP pelo Apache até JSP do WildFly, além de Pods Ready, sem reinícios observados. Não inferir estabilidade de longo prazo nem uso real de memória pós-deploy; isso ainda precisa de observação.
- **Próxima validação:** consultar `/api/v1/nodes/node01/proxy/stats/summary` para workingSet/availableBytes e `kubectl -n sre-java-lab get pods`/events; buscar OOMKilled, MemoryPressure e manter Python/PostgreSQL saudáveis. Desenvolver exercício de WAR, thread dump/JVM e respostas 503 com proxy como próxima aula.
- Atenção: WildFly 40.0.1 em UBI 9 é fallback para CPU de laboratório que não expõe x86-64-v3. Em produção avaliar versões suportadas e hardware/virtualização, atualizações de segurança e política de imagens aprovadas.

## INC-SRE-004 — Uso de memoria pos-recuperacao WildFly (13/11/2026)
- Usuário executou Kubelet Summary API em node01 após sucesso do fluxo Apache → WildFly 40.0.1.Final → JSP. Memória disponível estimada do nó: **893 MiB**.
- Working set de Pods em `sre-java-lab`: WildFly **371 MiB**, Tomcat **118 MiB**, Apache HTTP Server **8 MiB**, total **497 MiB**. Configuração do WildFly `requests.memory=256Mi`, `limits.memory=640Mi`; 371/640 ≈ 58% do limite, margem instantânea ≈269Mi dentro do limite.
- No instante anterior à instalação havia ~808Mi disponíveis no node01; agora ~893Mi. **Não inferir que o WildFly liberou RAM**, pois medições são snapshots com mudanças de carga/cache. Métricas de uso efetivo não substituem observação de estabilidade/pressão ao longo do tempo.
- **Próximo passo, ainda não executado:** confirmar `MemoryPressure=False`, reinícios e status de Pods, `kubectl -n sre-fullstack-lab get pods,pvc`, e executar `labs/fullstack-postgres/validate-fullstack.sh` para assegurar que PostgreSQL/API não foram impactados.
- Se estáveis, iniciar aula WAR Java + datasource JDBC/PostgreSQL com exercícios separados e controles para simular falhas, sem alterar aplicações produtivas.


## INC-SRE-004 — Pos-incidente validado e proxima aula JDBC preparada (13/11/2026)
- Usuário executou novamente a validação completa pós-recuperação do WildFly.
- `sre-java-lab`: `apache-gateway`, `tomcat-app` e `wildfly-app` todos **1/1 Running, 0 restarts**. WildFly estava há ~3m57s; Apache/Tomcat há ~32min.
- `controlplane` e `node01`: `MemoryPressure=False`, `KubeletHasSufficientMemory`.
- `sre-fullstack-lab`: Pods `incidents-api`, `incidents-web` e `postgres-0` **1/1 Running, 0 restarts**. PVC `data-postgres-0` **Bound**, capacidade 1Gi e StorageClass local-path.
- `validate-fullstack.sh` passou: SQL `srelab|0` (banco funcional, nenhum incidente nesta sessão); REST `/api/health` retornou `{"status":"ok","database":"connected","test":1}`; `/api/incidents` retornou `{"items":[]}`. Métricas Prometheus da API responderam, incluindo `/readyz` HTTP 200 acumulado 200 e HTTP 503 acumulado 2. **Dois 503 anteriores não indicam necessariamente erro atual**, visto que o health corrente passou. Não há prova ainda da duração da estabilidade a longo prazo.
- O banco está vazio, de acordo com `SELECT count(*)` e API; PVC existente não prova persistência entre sessões descartadas.
- **Próxima aula desenvolvida e publicada, mas não executada em runtime:** `labs/java-jdbc/` contém `index.jsp` JDBC somente leitura, `resources.yaml` com novo Tomcat limitado a 384Mi, initContainer que gera um WAR e baixa pgJDBC 42.7.14 do Maven Central, scripts `restore-jdbc.sh`/`validate-jdbc.sh` e README de investigação. A aplicação é instalada **no namespace sre-fullstack-lab** para consumir o Secret do PostgreSQL sem replicar segredos, e é opcional: não altera Tomcat/WildFly já executados.
- **Próximo comando para o usuário:** `cd ~/sre-killercoda-lab && git pull --rebase origin main && bash sre-killercoda-lab/labs/java-jdbc/restore-jdbc.sh`. Depois `bash sre-killercoda-lab/labs/java-jdbc/validate-jdbc.sh`. Se falhar, coletar logs de `package-war` e `tomcat` e `kubectl describe pod`, sem mexer no PostgreSQL.
- A instalação depende de conexão HTTPS do Pod com Maven Central para baixar driver; sem rede o initContainer falha e deve ser diagnosticado, não contornado desabilitando TLS. Nenhuma credencial foi versionada.


## Trilha Control-M — aula 01 publicada, pendente de execucao (13/11/2026)
- Objetivo da vaga analisada: administração ativa de Control-M/EM, Control-M/Server e Control-M/Agent; instalação, parametrização, upgrades, jobs, calendários, integrações, Shell/Batch/SQL, observabilidade e recuperação de incidentes. O usuário quer começar a aprender na prática para exercer funções operacionais, não apenas abrir/acompanhhar chamados.
- Verificados fontes oficiais BMC: Workbench é ambiente sem custo de licença de desenvolvimento, mas download na `distribution.bmc.com` exige conta com permissões no EPD, Identity Token e Docker. A documentação atual consultada informa `distribution.bmc.com/ctmem/workbench:9.27.5-GA`, container com **8 GiB mínimos**, Docker e porta **8443** livre (7005 para integração com agentes externos). Não cabe no cluster KillerCoda atual.
- Publicado módulo opcional `labs/controlm/`: `aula01-local.sh` (simulação de jobs com Shell no KillerCoda, sem Control-M), `jobs-sucesso.json` e `jobs-falha.json` (Job-as-Code Control-M, Folder/Job:Command/Flow Sequence), `README.md` (pré-check Windows/Docker/WSL2, EPD, instalação Workbench, build/run/monitor, diagnóstico).
- **IMPORTANTE:** script Shell e JSONs ainda não foram testados no KillerCoda nem no Control-M real. Os JSONs foram verificados por parse e estrutura via GitHub, mas o `ctm build` necessita de CLI/workbench, ainda indisponível. Nenhuma imagem ou licença BMC foi baixada, nenhuma alteração foi feita no cluster.
- **Próxima aula para executar AGORA:** `cd ~/sre-killercoda-lab && git pull --rebase origin main && bash sre-killercoda-lab/labs/controlm/aula01-local.sh`. Depois `bash sre-killercoda-lab/labs/controlm/aula01-local.sh --falhar` (termina com exit 42 intencional, JOB03 bloqueado). Coletar logs da pasta `/tmp/controlm-lab-...`.
- **Próximo passo para Workbench real:** verificar Docker/WSL2 no Windows e acesso EPD, sem compartilhar tokens. Se viável instalar conforme BMC, `ctm environment workbench::add`, `ctm build`, `ctm run`, `ctm run status <runId>`. Nunca afirmar experiência prática Control-M antes de executar de verdade.

## Checkpoint da sessão — 2026-11-13 21:42:16 UTC

Contexto: \`kubernetes-admin@kubernetes\`.

\`\`\`text
NAME           STATUS   ROLES           AGE   VERSION
controlplane   Ready    control-plane   8d    v1.37.1
node01         Ready    <none>          8d    v1.37.1
NAME                         READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES               SELECTOR
deployment.apps/drain-demo   2/2     2            2           21s   app          python:3.12-alpine   app=drain-demo
deployment.apps/web-blue     2/2     2            2           21s   web          busybox:1.36         app=sre-web,track=blue
deployment.apps/web-green    1/1     1            1           21s   web          busybox:1.36         app=sre-web,track=green

NAME                             READY   STATUS    RESTARTS   AGE   IP              NODE     NOMINATED NODE   READINESS GATES
pod/drain-demo-89554557b-4rtrh   1/1     Running   0          21s   192.168.1.175   node01   <none>           <none>
pod/drain-demo-89554557b-cc562   1/1     Running   0          21s   192.168.1.44    node01   <none>           <none>
pod/web-blue-5c57468c74-gsgws    1/1     Running   0          21s   192.168.1.73    node01   <none>           <none>
pod/web-blue-5c57468c74-z7bgw    1/1     Running   0          21s   192.168.1.110   node01   <none>           <none>
pod/web-green-6654db8d7b-pnrb6   1/1     Running   0          21s   192.168.1.118   node01   <none>           <none>

NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/drain-demo      ClusterIP   10.105.86.49   <none>        80/TCP    21s   app=drain-demo
service/sre-web         ClusterIP   10.96.123.57   <none>        80/TCP    21s   app=sre-web,track=blue
service/sre-web-green   ClusterIP   10.109.25.47   <none>        80/TCP    21s   app=sre-web,track=green
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                    AGE
drain-demo-zkx26      IPv4          8080    192.168.1.175,192.168.1.44   21s
sre-web-green-fdhts   IPv4          8080    192.168.1.118                21s
sre-web-nwv58         IPv4          8080    192.168.1.110,192.168.1.73   21s
\`\`\`

Notas: atualize manualmente o YAML e descreva mudanças importantes antes do próximo checkpoint.


## Control-M — aula 01 Shell confirmada em KillerCoda (13/11/2026)
- Usuário abriu nova sessão KillerCoda, recuperou `~/sre-killercoda-lab` via Git e executou a primeira aula Control-M **didática em Shell**, não o software oficial BMC.
- Execução normal: `bash sre-killercoda-lab/labs/controlm/aula01-local.sh` => `JOB_01_PRECHECK END OK`, `JOB_02_PROCESSAMENTO END OK`, `JOB_03_VALIDACAO END OK` e `SUCESSO: cadeia de 3 jobs finalizada.` Diretório de logs `/tmp/controlm-lab-20261113T213840Z-53470`.
- Execução de falha intencional: `bash sre-killercoda-lab/labs/controlm/aula01-local.sh --falhar` => `JOB_01_PRECHECK END OK`, `JOB_02_PROCESSAMENTO END NOTOK (ExitCode=42)`, `JOB_03_VALIDACAO WAIT/BLOQUEADO`. Diretório de logs `/tmp/controlm-lab-20261113T213853Z-53777`.
- **Conceitos validados:** retorno de processo, dependência sequencial, bloqueio de sucessor quando predecessor não está OK, pasta de logs por execução. Não inferir experiência operacional com Control-M Server, Agent, EM ou Workbench — ainda não instalados.
- **Próxima prática proposta, pendente de execução:** `cat /tmp/controlm-lab-20261113T213853Z-53777/JOB_02_PROCESSAMENTO.log` e `ls -lh /tmp/controlm-lab-20261113T213853Z-53777/`; confirmar erro intencional, rerun de toda a cadeia Shell sem flag (simulação de recuperação, **não rerun seletivo de job Control-M**). Em produção avaliar idempotência, duplicidade de dados e mudança autorizada antes de recuperar.
- **Trilha real BMC:** validar Docker/WSL2 e acesso ao Control-M Workbench oficial; depois executar `ctm build/run/status` para os fluxos JSON. Evitar alegar que a simulação equivale ao produto.


## Control-M — RCA e recuperacao completa da aula 01 Shell (13/11/2026)
- Usuário inspecionou o log real gerado pelo simulador: `/tmp/controlm-lab-20261113T213853Z-53777/JOB_02_PROCESSAMENTO.log`, contendo exatamente `ERRO INTENCIONAL: rotina ETL interrompida antes de gerar resultado`. Causa da falha simulada confirmada.
- Listagem do diretório de falha mostrou somente `JOB_01_PRECHECK.log` (52 bytes) e `JOB_02_PROCESSAMENTO.log` (67 bytes); **não existe log de JOB 03** porque a dependência o bloqueou antes de iniciar.
- Usuário simulou recuperação pela **nova execução completa da cadeia**, `bash sre-killercoda-lab/labs/controlm/aula01-local.sh`. Resultado: `JOB_01_PRECHECK END OK`, `JOB_02_PROCESSAMENTO END OK`, `JOB_03_VALIDACAO END OK`; `SUCESSO: cadeia de 3 jobs finalizada.` Novas evidências em `/tmp/controlm-lab-20261113T214418Z-65705`.
- **Competências demonstradas:** leitura de logs de execução, interpretação de ExitCode 42, distinção entre sucessor não executado e job falho, avaliação de dependências e validação de rerun de fluxo didático.
- **Não afirmar:** que houve rerun seletivo de job na ferramenta Control-M da BMC ou que o Control-M Workbench está instalado. O exercício segue sendo Shell, não produto comercial.
- Próxima aula: verificar `python3 -m json.tool` nos dois arquivos `labs/controlm/jobs-*.json`, explicar Job-as-Code e `Flow.Sequence`, depois preparar Docker Desktop/WSL2 (em Windows local) e autorização de download via BMC EPD para Workbench real. No Linux KillerCoda atual, não instalar Workbench devido ao mínimo de 8GiB para container.


## Control-M — Aula 02 Job-as-Code JSON sintaxe validada (13/11/2026)
- No KillerCoda, o usuário fez `git pull --rebase origin main` com Fast-forward `ed70e33..2a80565` e executou `python3 -m json.tool` sobre `sre-killercoda-lab/labs/controlm/jobs-sucesso.json` e `jobs-falha.json`.
- **Ambos os JSONs válidos sintaticamente**: `SRE_LAB_CONTROLM_01` com jobs `JOB_01_PRECHECK`, `JOB_02_PROCESSAMENTO`, `JOB_03_VALIDACAO` e `Flow.Sequence` correspondente; `SRE_LAB_CONTROLM_FALHA` com `JOB_01_PRECHECK`, `JOB_02_FALHA` com `sh -c 'echo FALHA_INTENCIONAL; exit 42'`, `JOB_03_VALIDACAO` e dependências `Flow.Sequence`. Cada folder traz `Type: Folder`, `RunAs: workbench`, `Job:Command`.
- Estrutura `Folder` / `Job:Command` / `Flow: {Type: Flow, Sequence: [...]}` confrontada com exemplo oficial `https://github.com/controlm/workbench` e `https://github.com/controlm/automation-api-quickstart/blob/master/control-m/101-create-first-job-flow/AutomationAPISampleFlow.json`, compatível em forma.
- **Não foi realizado `ctm build`, `ctm run` ou `ctm run status`**: sem CLI/Workbench oficial no KillerCoda, apenas sintaxe JSON e correspondência estrutural. Não declarar experiência real com a BMC até executar tais comandos.
- Próxima etapa: em PowerShell do Windows local, verificar `wsl --status`, `docker version`, `docker info --format '{{.MemTotal}}'` e uso da porta 8443 antes de tentar Workbench oficial no computador; requer memória disponível suficiente e conta com permissão BMC EPD. Não divulgar tokens.


## Control-M — Precheck executado no Linux KillerCoda, nao no Windows (13/11/2026)
- O usuario executou `wsl --status`, `docker version`, `docker info --format '{{.MemTotal}}'` e `Get-NetTCPConnection` no terminal `root@controlplane` do **Linux KillerCoda**, nao no PowerShell do computador Windows.
- `wsl: command not found` e `Get-NetTCPConnection: command not found` sao esperados nesse terminal, ja que sao comandos Windows; **nao recomendar apt install wsl nesse Linux**.
- Docker Client e Docker Engine **29.1.3** estao operacionais no KillerCoda. `docker info --format '{{.MemTotal}}'` reportou **2355339264 bytes (~2,19 GiB de memoria total)**, insuficiente para Control-M Workbench oficial com minimo de ~8 GiB de RAM para container.
- A plataforma KillerCoda e efemera e utiliza muita memoria em outros componentes; nao tentar instalar BMC Workbench nela.
- **Proximo passo pendente:** abrir PowerShell nativo no notebook Windows do usuario (fora da janela/terminal KillerCoda) e executar os mesmos prechecks de Windows para WSL2/Docker e porta 8443. Ainda nao sabemos se Windows tem Docker Desktop e WSL2 instalados e funcionando. Recomendar observar recursos disponiveis e garantir autorizacao BMC EPD; nao solicitar credenciais na conversa.


## Control-M — precheck PowerShell Windows: WSL e Docker ausentes (13/11/2026)
- Usuário executou os comandos de pré-check **agora no PowerShell do computador Windows** (não no KillerCoda).
- `docker info --format '{{.MemTotal}}'` e `docker version` retornaram `docker : O termo 'docker' não é reconhecido`. Não há comando Docker disponível no Windows (não instalado ou ausente do PATH).
- `wsl --status` retornou `O Subsistema do Windows para Linux não está instalado. Você pode instalar executando 'wsl.exe --install'.`
- `Get-NetTCPConnection -LocalPort 8443 -State Listen -ErrorAction SilentlyContinue` não exibiu dados, sugerindo nenhum listener identificado na porta naquele instante; isso não garante futura disponibilidade.
- **Plano de instalação recomendado:** antes de usar o Workbench BMC, abrir PowerShell como administrador e executar `wsl --install`, reiniciar, conferir `wsl --status` e `wsl --list --verbose`. Depois baixar e instalar Docker Desktop via site oficial e verificar `docker version`/ `docker info`. Validar Windows suportado, virtualização firmware e RAM antes de iniciar Docker. Documentação Microsoft: https://learn.microsoft.com/pt-br/windows/wsl/install/ ; Docker: https://docs.docker.com/desktop/setup/install/windows-install/.
- Controle-M Workbench BMC **continua não instalado**: exige Docker/WSL2 operacionais, ~8 GiB livres para o container e acesso autorizado BMC EPD/Identity Token; não solicitar token no chat nem instalar imagem não oficial. Na máquina de 16GB pode haver pressão de RAM se houver VMs pesadas simultâneas.
- A próxima resposta do usuário deve conter resultado de `wsl --install` ou `wsl --status`/ `wsl --list --verbose` pós-reinício, para orientar o Docker Desktop. Nenhuma alteração no computador foi realizada pelo assistente.


## Control-M — manual completo de instalacao Server 9.0.27 publicado (14/11/2026)

- Usuário pediu manual detalhado para instalar e configurar **Control-M/Server real em servidor Linux**, além da simulação Shell e do Workbench Docker.
- Consultada documentação **BMC 9.0.27 publicada em 12/11/2026**: [Installation](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Introduction_to_Control-M_Installation.htm), [Server Installation](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Installation.htm), [Prerequisitos UNIX/Linux](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_pre-installation_procedures_on_UNIX.htm), [Full requisitos](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_full_installation_system_requirements.htm), [Java](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Java_Installation.htm), [Firewall](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Firewall.htm), [EM](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Management.htm), [Backup](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Database_Backup_and_Restore.htm).
- Esclarecida a diferença entre Server-only e Full: Server instala Agent local e pode usar PostgreSQL BMC; para console EM é necessária implantação separada. BMC recomenda **distribuído para produção**.
- Requisitos oficiais: Server **4vCPU, 8 GiB + 4 GiB para PostgreSQL local, 40 GiB**; Full Installation **4vCPU, 20 GiB + 4GiB DB local, 100 GiB disco**. Notebook pessoal 16GiB e KillerCoda 2GiB insuficientes para Full.
- Publicado [MANUAL-INSTALACAO-CONTROL-M-SERVER-LINUX.md](../labs/controlm/MANUAL-INSTALACAO-CONTROL-M-SERVER-LINUX.md) com instalação guiada em RHEL9, tcsh/conta 8 caracteres, CheckReq, Java externo, setup.sh, silent XML, script systemd, EM, Agent, portas TLS, backup, recovery e upgrade.
- Publicado [precheck-server-linux.sh](../labs/controlm/precheck-server-linux.sh) que apenas lê recursos da VM, sem mudar serviços.
- Criado PDF local para leitura como anexo de conversa (arquivo no GitHub Markdown é a versão completa/atualizável).
- **Status:** manual e preflight PUBLICADOS e **não executados em servidor real**. Próximo requisito operacional: obter acesso/licença ao BMC EPD e VM Linux homologada; realizar pré-check e validar instalador oficial, sem divulgar credenciais nem causar custos não aprovados.
