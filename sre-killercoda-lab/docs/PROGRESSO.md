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
