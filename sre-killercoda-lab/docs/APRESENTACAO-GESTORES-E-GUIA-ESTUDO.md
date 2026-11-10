# Laboratório SRE/DevOps — apresentação para gestores e guia de estudo

Data de referência: 07/11/2026
Repositório: https://github.com/lvbeserra/sre-killercoda-lab
Aviso: laboratório educacional, com pagamentos fictícios, sem transações reais nem garantias de produção.

## Resumo executivo — fala de 90 segundos
Construímos uma plataforma reprodutível de experimentos em Kubernetes para validar confiabilidade de aplicações, automação, deploy seguro, mensageria assíncrona e observabilidade. A infraestrutura foi recuperada a partir do GitHub em sessões temporárias do KillerCoda. Demonstramos Blue/Green, Rolling Update, graceful shutdown, Apache, Kafka, RabbitMQ, Python Bridge e Worker. Nos testes, comprovamos encaminhamento automático Kafka -> RabbitMQ -> Worker, recuperação do consumidor após interrupção, tratamento de duplicatas por ID, dead-letter queue para mensagens inválidas e métricas que se atualizam conforme o processamento. Também medimos disponibilidade e latência de endpoints internos e registramos falha e recuperação do Apache em histórico SQLite. Propomos evoluir isso, em ambiente corporativo isolado e aprovado, para laboratório de validação de mudanças, capacitação, padronização e prevenção de incidentes. Não se trata de substituir produção; trata-se de praticar e provar mudanças antes de expor sistemas críticos.

## Slides sugeridos (12)
1. Desafio: mudanças arriscadas, incidentes, falta de ambiente controlado de testes, conhecimento pouco replicável.
2. Proposta: laboratório isolado de SRE e automação, recuperável por configuração em Git.
3. Infraestrutura: Linux, containers, Kubernetes com dois nós, redes Cilium/eBPF.
4. Estratégias de release: Blue/Green (duas versões), Rolling Update, readiness, graceful shutdown e SIGTERM.
5. Fluxo de negócio fictício: Kafka -> bridge Python -> RabbitMQ -> notification-worker -> ACK.
6. Resiliência: pausar Worker; mensagem permanece em fila; restaurar e confirmar ACK.
7. Integridade: dois eventos iguais; deduplicação por pagamento_id usando SQLite/PVC; 2 ACKs, 1 processamento.
8. Tratamento de falhas: DLQ RabbitMQ retém mensagem sem pagamento_id, sem descarte silencioso.
9. Observabilidade: métricas Prometheus, logs JSON, coleta sintética a cada 30 segundos com SQLite/PVC.
10. Engenharia de confiabilidade: SLI, SLO, error budget, burn rate e regras multiwindow. Separar simulação de medição real.
11. Evidências: 120/120 consultas durante Rolling Update; incidente Apache registrado; resultados reais da mensageria.
12. Proposta corporativa: ambiente isolado, governança, segurança, evolução em fases e critérios mensuráveis de aprovação.

## Tecnologias e analogias
- Linux: fundação do ambiente; administra processos, rede, armazenamento e permissões.
- Containers: embalagens padronizadas da aplicação; imagem contém dependências. O laboratório usa imagens containerizadas; não pressupor Docker Engine no nó, que usou containerd.
- Kubernetes: coordenador de orquestra; Pods executam containers, Deployments reconciliam o número desejado de réplicas, Services dão um endereço estável, ConfigMaps guardam parâmetros não secretos e Secrets guardam credenciais.
- Cilium: camada de rede e políticas; eBPF é um mecanismo do kernel que permite processamento eficiente de tráfego e telemetria; o Cilium com kubeProxyReplacement foi observado em testes anteriores, não é instalado pelo iniciar.sh.
- Apache HTTP: recepção da aplicação HTTP.
- Kafka 4.1.2: trilha de eventos e leitura por offsets; usa KRaft standalone em um broker, tópico pagamentos-simulados com uma partição e fator de réplica 1. Não é tolerante a perda do broker.
- RabbitMQ 4.1-management: correio de tarefas: fila, entrega e confirmação ACK. DLQ guarda rejeitadas. Um ACK confirma consumo, não significa que efeitos externos reais sejam exatamente uma vez.
- Python: lógica da bridge e do worker.
- SQLite: cadastro de IDs fictícios processados para deduplicação. Uma instância do worker e PVC local-path; não resolve transação distribuída nem múltiplos workers.
- Prometheus: formato de métricas /metrics exposto pela aplicação; Prometheus Server/Grafana não foram instalados nessa etapa. O RabbitMQ também expõe métricas próprias.
- Git/GitHub: código e configurações declarativas sob controle de versão; não recupera discos, Secret nem histórico de mensagens em memória.
- SRE: prática de definir confiabilidade usando indicadores, objetivos e orçamento de erro, mais testes, automação e resposta a incidentes.

## As escolhas de configuração — por que fizemos
- Kubernetes dois nós Ready: permite estudar distribuição de Pods e comportamento multi-node; não implica HA de produção do control plane.
- Namespaces separados: sre-release-lab (Blue/Green/Drain), sre-cpu-lab (benchmarks), sre-middleware-lab (mensageria/observabilidade), para organização e menor chance de alterações cruzadas.
- Deployment: declara replicas desejadas e permite rollout/rollback e auto-reconciliação.
- Readiness Probe: indica se o Pod pode servir tráfego. RabbitMQ teve problema com configuração antiga e foi corrigido com rabbitmq.conf; a startup probe foi alterada para TCP 5672 para ser leve nesse ambiente.
- Rolling Update maxUnavailable=0, maxSurge=1 no drain-demo: manter as réplicas antigas prontas enquanto uma nova sobe, respeitando capacidade do nó. Não garante ausência absoluta de falhas.
- preStop sleep 5s e terminationGracePeriodSeconds=30: permitir retirar Pod da rota e finalizar requisições; /slow dura 12 segundos; sinais SIGTERM tratados em Python.
- Kafka: um broker KRaft e 1 partição; reduz consumo no treinamento. Kafka é log de eventos com offsets, não fila simples com exclusão automática após ACK.
- Bridge: RabbitMQ publisher confirms antes do commit manual do offset Kafka. Em uma falha entre publicar e commitar, pode ocorrer duplicata; entrega at-least-once.
- Worker: ACK após INSERT OR IGNORE + COMMIT SQLite para deduplicar; mensagem inválida recebe basic_reject(requeue=False) e segue para DLQ por policy. Se houvesse pagamentos reais, precisaria idempotência no banco e efeitos externos, outbox, auditoria, segurança etc.
- PVC de 64Mi: mantém SQLite durante troca do Pod enquanto o volume e VM existirem, mas não sobrevive à destruição do KillerCoda.
- Kafka e RabbitMQ emptyDir: dados temporários; adequados a laboratório descartável e não a produção.
- /metrics em 9100: contadores de processed, duplicate_skipped, invalid, ack, db_error, reconnect; sem IDs de pagamento como labels para evitar alta cardinalidade e vazamento.
- Observer: prova HTTP Apache e /metrics a cada 30s; grava sucesso/latência em SQLite/PVC; não detecta queda total do próprio cluster e não observa usuários externos.
- 99,9%/30 dias: hipótese de SLO, não objetivo já alcançado em produção. Error budget baseado em requisições é diferente de disponibilidade baseada em tempo.
- Segurança: Secret RabbitMQ gerado no cluster; não publicar tokens, kubeconfig ou credenciais no Git; RBAC e políticas adicionais são trabalhos futuros.
- Infra ainda limitada: CPU/RAM do KillerCoda; em uma coleta, soma de limites de memória no node01 era 189% da capacidade — overcommit de limites, não uso efetivo medido.
- Dynatrace: integração prevista, não implantada; requer licença/tenant/token/permissões e dimensionamento. Não apresentar como ferramenta ativa no laboratório.

## Evidências reais para citar
- Blue/Green: Blue v1 com 2 Pods, Green v2 com 1 Pod; as duas versões foram implantadas e testadas, mas o cutover de selector do Service principal não foi comprovado.
- Rolling Update do drain-demo: 120 de 120 consultas curtas /ready responderam em teste; não afirmar zero downtime garantido em todos os cenários.
- Graceful shutdown /slow: chamada de 12 segundos concluiu apesar do SIGTERM e encerramento.
- Middleware: Apache HTTP 200, Kafka tópico pagamentos-simulados saudável, RabbitMQ Ping succeeded e 1/1 Ready.
- Fluxo automático: pagamento fictício PAG-WORKER-20261107T210512-25693; bridge FORWARDED em Kafka partição 0 offset 2; Worker ACK para mesmo ID.
- Resiliência: durante pausa do Worker, 1 mensagem pronta e 0 não confirmadas; após restaurar Worker, ACK e fila zerada.
- Duplicidade antes da correção: 2 FORWARDED, 2 ACK, 2 processamentos para mesmo ID.
- Idempotência após correção: 2 FORWARDED, 2 ACK, 1 NOTIFICATION_PROCESSED, 1 DUPLICATE_SKIPPED.
- DLQ: mensagem sem pagamento_id fez mensagens_ready ir de 0 a 1 na notificacoes-pagamentos-dlq.
- Métricas ao vivo: processed=1, duplicate=1, ack=2, invalid=1; sem DB errors nem reconnects na coleta.
- SLI sintético de 20 amostras por endpoint: Apache 100% sucesso, p50=5.1ms e p95=8.8ms; /metrics 100%, p50=5.4ms e p95=7.1ms.
- Error budget: 10.000 requisições com 15 falhas é 99,85% de disponibilidade, 5 falhas a mais que budget proporcional de 10 e burn=1,5x.
- Multiwindow simulado: PAGE_FAST com 16x(1h)/20x(5m); PAGE_SUSTAINED com 8x(6h)/8x(30m). Não são alertas em produção.
- Observer histórico: inicialmente 5/5 amostras OK, cobertura 96s. Após incidente Apache, relatório em 5min: 13 amostras, 11 sucessos, 2 falhas, 84,615% observado e burn de amostra 153,85x; /metrics manteve 13/13 OK; cobertura 276s e >= 90%.
- Nova verificação check-observed-burn-rate.sh foi publicada, ainda não há saída fornecida do teste em cluster.

## Comandos para demonstrar ao vivo

Restaurar num KillerCoda Kubernetes novo (não reclonar se pasta já existir):

    git clone https://github.com/lvbeserra/sre-killercoda-lab.git
    cd sre-killercoda-lab
    bash iniciar.sh

Conferir contexto, nodes e workloads:

    kubectl config current-context
    kubectl get nodes -o wide
    kubectl -n sre-release-lab get deploy,pods,svc -o wide
    kubectl -n sre-middleware-lab get deploy,pods,svc,pvc -o wide

Verificar implantação e logs:

    kubectl -n sre-middleware-lab rollout status deployment/payment-bridge
    kubectl -n sre-middleware-lab logs deployment/payment-bridge --tail=30
    kubectl -n sre-middleware-lab logs deployment/notification-worker --tail=30

Verificar Kafka, RabbitMQ e DLQ:

    kubectl -n sre-middleware-lab exec deployment/kafka -- /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --describe --topic pagamentos-simulados
    kubectl -n sre-middleware-lab exec deployment/rabbitmq -- rabbitmqctl -q list_queues name messages_ready messages_unacknowledged

Verificar métricas e histórico:

    bash sre-killercoda-lab/labs/test-metrics.sh
    bash sre-killercoda-lab/labs/report-sre-observer.sh 5
    bash sre-killercoda-lab/labs/check-sre-alerts.sh
    bash sre-killercoda-lab/labs/check-observed-burn-rate.sh

Validar fluxo ponta a ponta e consistência (apenas no laboratório):

    bash sre-killercoda-lab/labs/test-notification-worker.sh
    bash sre-killercoda-lab/labs/test-idempotencia.sh
    bash sre-killercoda-lab/labs/test-dlq.sh

Confirmar checkpoint Git:

    tail -30 /tmp/sre-checkpoints.log
    git status -sb

## Argumentação de implantação no ambiente corporativo
Propor um laboratório isolado, não um rollout imediato de produção. Começar com um cluster pequeno controlado por infraestrutura, RBAC de mínimo privilégio, secret management, rede segregada, observabilidade corporativa e política clara de custos/limpeza. Escolher um serviço fictício ou aplicação interna não crítica. Executar ensaios replicáveis de Rolling Update, falha de Worker, duplicatas, DLQ, observabilidade, rollback e auditoria. Só considerar migração de sistemas reais após aprovação de segurança, arquitetura, operações e requisitos de negócio.

Critérios úteis e verificáveis: tempo de reconstrução de ambiente, proporção de testes reproduzíveis, tempo de detecção em testes controlados, sucesso de rollback, evidência de não duplicação, fila/DLQ monitoradas, limites e consumo reais, mudanças documentadas. Não prometer percentuais de economia ou redução de incidentes sem dados anteriores.

## Perguntas difíceis e respostas
- Isso está pronto para produção? Não. Os brokers são single-node e usam emptyDir; faltam HA, backup, TLS, RBAC rigoroso, gestão de segredos, CI/CD e observabilidade fora do cluster.
- Por que Kafka e RabbitMQ juntos? Kafka é ótimo para histórico e streams de eventos com offsets; RabbitMQ para fila de trabalho/roteamento e ACK do consumidor. Juntos quando padrões justificam, não por obrigação.
- Se RabbitMQ confirmar e a Bridge cair antes do commit Kafka? O evento pode ser republicado. A deduplicação no Worker reduz efeito duplicado desse fluxo, mas não dá exactly-once global.
- O que protege pagamentos duplicados? Aqui só simulação. SQLite registra ID antes do ACK e ignora repetição. Pagamento real exige deduplicação transacional no serviço financeiro e trilha auditável.
- Se o KillerCoda expirar? Git salva código e manifests; dados das filas e PVCs do cluster são perdidos. Recriar exige clone e iniciar.sh.
- Como medimos disponibilidade? SLI sintético HTTP e métricas /metrics; as amostras internas não comprovam SLO real de usuários e não cobrem queda total do cluster.
- Por que P95 subiu? Uma amostra lenta de inicialização afeta percentis quando existem poucos pontos; avaliar tamanho amostral, distribuição e janela.
- Dynatrace já está funcionando? Não. Está planejado e documentado, requer acesso, recursos e integração em cluster corporativo.
- Cilium garante segurança sozinho? Não. É mecanismo de rede e políticas; políticas precisam ser definidas, revisadas e aplicadas. RBAC/Secrets e hardening continuam necessários.
- Ter dois nós significa alta disponibilidade? Não necessariamente: controlplane pode ser único, brokers têm uma réplica e armazenamento local.
- Como justificar custo? Demonstrar validação pré-produção e métricas de operação em piloto; dimensionamento e ROI dependem dos custos e incidentes reais do negócio.

## Plano de evolução
Fase 1 (já comprovada no laboratório): arquitetura, deploy, mensageria, recuperação, idempotência, DLQ, métricas, probes sintéticos e coleta histórica inicial.
Fase 2 (próximo laboratório): validar check-observed-burn-rate; introduzir métricas persistentes fora do cluster e alertas reais com janelas; testes de restart e retenção.
Fase 3: Dockerfile versionado e CI/CD (build, testes, scanning, promoção entre ambientes, rollback), GitOps com Argo CD e políticas Cilium/RBAC.
Fase 4: Dynatrace/OTel com rastreamento distribuído e dashboards; HA Kafka/RabbitMQ e storage persistente; backup e recovery testado.
Fase 5: piloto corporativo isolado, runbooks, KPIs de eficácia e governança para expansão.

## Glossário oral rápido
Pod = menor unidade agendada de execução no Kubernetes.
Deployment = controlador que mantém réplicas/versão desejadas.
Service = acesso estável e balanceamento para Pods.
Namespace = separação lógica de recursos.
Readiness = condição para receber tráfego.
Liveness = condição para reiniciar aplicação travada, se configurada.
Startup Probe = tolerância à inicialização sem falsos reinícios.
SIGTERM = pedido de encerramento gracioso.
preStop = hook antes da parada.
Rolling Update = troca gradual de Pods.
Blue/Green = manter duas versões independentes e alternar tráfego por mecanismo de roteamento.
KRaft = consenso/metadados nativos do Kafka sem ZooKeeper.
Offset = posição de leitura de mensagem no log Kafka.
Publisher confirm = confirmação do broker RabbitMQ de aceitar publicação.
ACK = consumidor confirma processamento para remoção da fila.
DLQ = fila de mensagens rejeitadas.
Idempotência = reexecutar operação sem repetir o efeito.
PVC = requisição de volume persistente por aplicação.
SLI = indicador medido da confiabilidade.
SLO = objetivo definido para esse indicador, com janela.
Error budget = parcela permitida de falhas para o SLO.
Burn rate = velocidade de consumo do orçamento de erros.
P50/P95 = percentis da distribuição de latência.
GitOps = sincronizar o estado do cluster com configurações declarativas versionadas.

## Referências
Repositório: https://github.com/lvbeserra/sre-killercoda-lab
Progresso: https://github.com/lvbeserra/sre-killercoda-lab/blob/main/sre-killercoda-lab/docs/PROGRESSO.md
Google SRE Workbook: https://sre.google/workbook/alerting-on-slos/
Dynatrace Kubernetes: https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s

## Nova expansão — Infraestrutura Sênior Híbrida (baseada na vaga)
Além de SRE/Kubernetes, o curso passa a cobrir conceitualmente servidores Windows/AD, VMware/Hyper-V, SAN/NAS/backup, rede/VPN/VLAN/firewall/LB, Azure/AWS/GCP, Terraform/Ansible/ARM/CloudFormation, monitoramento corporativo, segurança/compliance, FinOps e migrações. Existe auditoria read-only Kubernetes e inventário Windows em PowerShell para iniciar os exercícios. **Os demais módulos continuam planejados e não são funcionalidades já implantadas**.

O documento de escopo completo é [TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md](TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md), e a prática de fala para reuniões e entrevistas está em [ENTREVISTA-INFRA-SENIOR.md](ENTREVISTA-INFRA-SENIOR.md).

Para gestores, apresentar esta expansão como **piloto de capacitação, padronização e validação de operações híbridas**, não como plataforma de produção nem como evidência de que todos os produtos citados já estão integrados.
