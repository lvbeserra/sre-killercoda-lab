# Trilha de especialização — DevOps Sênior / Operações GCP

**Origem:** descrição da vaga "Analista DevOps Senior — Operações GCP" enviada pelo estudante em 13/11/2026.
**Objetivo:** transformar os requisitos específicos da vaga em aulas teóricas, laboratórios reproduzíveis, evidências de incidentes, runbooks e entrevistas técnicas. O material **não** representa experiência comprovada em produção GCP.

## Onde esta trilha se encaixa no curso

- Pré-requisitos já praticados no SRE KillerCoda: Kubernetes (Pods, Deployments, Services, PVC), API Python + Nginx + PostgreSQL, Zabbix/Grafana/Prometheus, SLI/SLO, incidentes sintéticos e bloqueio SQL, shell, Git e GitHub.
- Familiaridade prévia com AWS/Azure/Terraform auxilia, mas não equivale à administração prática do GCP.
- A trilha é **opcional, independente e não é executada automaticamente por bash iniciar.sh**. Assim não cria recursos ou cobranças na nuvem.
- Máquina atual: notebook com 16 GiB de RAM; preferir uma VM Ubuntu + K3s local de 2 vCPU e ~6 GiB, desabilitando middleware pesado nas primeiras aulas, ou usar o KillerCoda. GKE real exige projeto/billing e capacidade de custear recursos.

## Matriz fiel à vaga e resultado esperado

| Domínio pedido na vaga | Exercício / evidência que produzir | Condição |
|---|---|---|
| Liderança L3, incidentes P1, War Rooms e post-mortems | Simular incidente com linha do tempo, comunicação, decisão e RCA blameless | Local |
| Disponibilidade, capacidade, upgrades e escalabilidade | Diagnóstico kubectl, requests/limits, probes, HPA e política de rollback | Local primeiro; GKE depois |
| GKE, Compute Engine e Cloud Run | Arquitetura GKE Standard/Autopilot, VM, serviço serverless e critérios de escolha | GCP real opcional |
| IAM, VPC, firewall, DNS, Load Balancing | Plano de redes, service accounts, menor privilégio, fluxo de tráfego e conectividade | Offline + cloud opcional |
| Cloud Storage, Cloud SQL, Bigtable e Pub/Sub | Escolher storage, SQL/NoSQL, filas, confiabilidade e backup; mapear pipeline Kafka/Rabbit atual a Pub/Sub | Offline + cloud opcional |
| Terraform avançado e módulos | Criar desenho de módulos, variáveis, outputs, state remoto, validação e aprovação antes de apply | Local no início |
| CI/CD e GitOps | Pipeline lint/test/scan/plan/build/deploy/revert; GitHub Actions, Cloud Build e ArgoCD | GitHub local primeiro |
| Observabilidade GCP / SRE | Métricas, logs, traces, alertas, dashboard, SLI/SLO/burn rate e runbook | Local; Cloud Operations depois |
| FinOps e assessment | Inventário, tags/labels, quotas, requests ociosos, estimativa, forecast e recomendações | Sem billing no início |
| Segurança DevSecOps | IAM, Secret Manager, Workload Identity Federation for GKE, Cloud Armor, VPC Service Controls, RBAC e auditoria | Design + sandbox opcional |
| Disaster Recovery | Análise de dependências, matriz RTO/RPO, backup + restore, decisão regional e simulação de failover | Local; GCP posterior |
| Kanban, Scrum, Discovery, mentoria | P1 Kanban, backlog Scrum, assessment, workshop N1/N2, reuniões técnicas com cliente | Simulado, documentação |

## Sequência sugerida: 8 semanas (5–7 horas/semana)

### Semana 1 — Fundamentos da plataforma GCP + redes

**Aprender:** organização/folders/projects, billing, regiões/zonas, quotas, IAM (usuários, grupos, service accounts e papéis), VPC, subnets, firewall, DNS, NAT, Load Balancing, Cloud Armor, Cloud Storage e Compute Engine.

**Prática sem custo de nuvem:** desenhar VPC com duas sub-redes, app privada + acesso controlado, matriz IAM por função, fluxos de entrada/saída e plano de DNS. Documentar riscos, diagramas e Terraform de validação local.

**Entrega:** arquitetura, inventário de riscos, matriz de menor privilégio.

### Semana 2 — Kubernetes operacional → GKE

**Aprender:** GKE Standard vs Autopilot, node pools, scheduling, requests/limits, HPA, readiness/liveness/startup probes, RBAC, namespaces, NetworkPolicy, PersistentVolume/PVC, services, ingress/gateway, identidade de workloads, upgrades e rollbacks.

**Prática no lab atual:** provocar e diagnosticar Pod Pending, ImagePullBackOff, CrashLoopBackOff ou readiness falhando, registrando kubectl describe, events, logs e plano de mitigação. Usar ferramentas existentes antes de criar novos clusters.

**Entrega:** runbook de operação GKE, checklist upgrade e plano de rollback.

### Semana 3 — Terraform e governança de mudança

**Aprender:** providers, módulos, variáveis, outputs, remote state + locking quando aplicável, import, drift, revisão de plano, política de aprovação, segregação dev/hml/prd e segurança no state.

**Prática segura:** terraform fmt -check, init -backend=false (somente se o exercício exigir providers), validate e plano sem aplicar em GCP. Nada de terraform apply automático; revisar permissões e custo estimado antes.

**Entrega:** módulo versionado de rede/serviços, README com arquitetura, pipeline de validação e análise de risco.

### Semana 4 — CI/CD, GitOps e operações de aplicação

**Aprender:** GitHub Actions, Jenkins/GitLab, Cloud Build, registry, versionamento imutável, ArgoCD, progressive delivery, blue/green, rollback, supply chain e controles de promoção.

**Prática local:** automatizar lint/testes da API Python do repo; validar manifeste Kubernetes, simular deploy blue/green e registrar rollback com evidências. Depois comparar pipeline GCP Cloud Build/GKE/Cloud Run.

**Entrega:** pipeline com gates, plano de deploy, rollback testado e registro de mudança.

### Semana 5 — Observabilidade profunda, SLI/SLO, tracing

**Aprender:** Cloud Monitoring, Cloud Logging, Cloud Trace, métricas de golden signals, erro/orçamento, alertas, PromQL, dashboards, correlação logs/traces, p95/p99 e anti-padrões de alerta.

**Prática local:** instrumentar API/serviço existente, coletar latência e falhas, explicar um 200 lento vs um 5xx rápido; correlacionar Nginx, Python e SQL. Usar a medição existente 82ms vs 2003ms apenas como demonstração, não como p95 estatístico.

**Entrega:** definição de 2 SLIs, 1 SLO, alerta proporcional ao burn rate, painel/runbook e evidências.

### Semana 6 — Dados, mensageria, resiliência e DR

**Aprender:** Cloud SQL x Bigtable, PostgreSQL gerenciado, Cloud Storage (classes/retention), Cloud Pub/Sub (ack, redelivery, DLQ, idempotência), Cloud Run, backups, RPO/RTO, resiliência zonal/regional, custos de HA.

**Prática local:** executar incidente de lock PostgreSQL já validado; correlacionar backlog Kafka/RabbitMQ; criar tabela RPO/RTO e testar backup + restore **em instância separada**.

**Entrega:** plano de recuperação, evidência de restauração, topologia e relatório de gargalos.

### Semana 7 — FinOps, segurança, governança e Discovery

**Aprender:** budgets/alerts, relatórios de custo, labels, rightsizing, autoscaling, recursos órfãos, controle de egress, IAM mínimo, Secret Manager, Workload Identity Federation for GKE, Cloud Armor/VPC Service Controls, gestão de vulnerabilidades e auditoria.

**Prática local:** assessment de recursos Kubernetes read-only; mapear riscos, estimar custos por faixa no Google Cloud Pricing Calculator antes de criar ambiente, documentar prioridades e decisões. **Budget alert não é limite de gasto nem trava o faturamento.**

**Entrega:** apresentação executiva de 1 página com riscos, backlog Kanban/Scrum, custo estimado, ganho e métricas.

### Semana 8 — Simulado de operação sênior / War Room

**Cenário:** cliente relata degradação de checkout. App em Kubernetes, banco SQL, serviço de eventos. Definir severidade P1/P2, conduzir triagem, conter impacto, comunicar stakeholders, recuperar serviço, monitorar SLO e escrever post-mortem blameless.

**Exigir como evidência:** linha do tempo UTC, sintoma x hipótese, kubectl get/describe/logs/events, SQL pg_stat_activity, taxa de falha e latência, reversão, decisão de escalonamento, impacto, causa demonstrada, 3 ações preventivas com responsáveis e prazos.

**Entrega final:** War Room simulada (15min), runbook N1/N2 e post-mortem com 30/60/90 dias de melhorias.

## Níveis de prática: não confundir os resultados

| Nível | O que é possível afirmar |
|---|---|
| 1 — Exercício local | "Investiguei Kubernetes, PostgreSQL e fluxo API em laboratório controlado" |
| 2 — Planejamento GCP | "Desenhei arquitetura GKE/VPC/IAM e validei IaC sem provisionamento" |
| 3 — Sandbox GCP real | "Criei e investiguei GKE/Cloud SQL/etc. em projeto de laboratório" **somente após realmente executar e medir** |
| 4 — Produção | Exige participação real em ambientes corporativos; não decorre de certificados ou labs |

## Como será a aula prática (modelo fixo)

1. **Contexto de incidente:** cenário, impacto, SLI/SLO e severidade.
2. **Hipóteses:** três causas plausíveis ordenadas pelo risco e sinais.
3. **Coleta read-only:** comandos para kubectl, logs, métricas, rede e dependências.
4. **Causa demonstrada:** evidência que diferencia correlação de causalidade.
5. **Mitigação/rollback:** procedimento com segurança, aprovações e condição de abortar.
6. **Validação:** comparação antes/depois, sinais de recuperação e ausência de regressão.
7. **Registro:** runbook, post-mortem sem culpados, evidências e explicação oral de 30s.

## Segurança e custos: regra para toda a trilha

- **Nunca executar deploy, enable APIs, GKE, Cloud SQL, Pub/Sub, Bigtable, NAT, Load Balancer ou recursos pagos automaticamente pelo iniciar.sh.**
- Para exercícios com GCP: projeto de laboratório separado; billing controlado; consultar preços/quota/region atualizados; aprovar escopo; aplicar etiquetas; registrar custo previsto; planejar teardown e validar a remoção.
- Evitar credenciais permanentes: usar autenticação interativa apropriada e identidade de workloads; não salvar service account keys, tokens, kubeconfig, Terraform state, senhas ou dados reais no Git.
- Nenhuma cobrança ou implantação GCP está autorizada por esta documentação.
- Scripts locais fazem diagnósticos read-only. GKE/OpenShift e bancos gerenciados exigem acesso/projeto próprios e não são reproduzidos apenas com um Kubernetes local.

## Atividades de mentoria, operação e gestão

- **War Room P1:** quem lidera, quem faz mitigação, quem comunica, quem documenta, periodicidade dos informes, critérios de resolução e handoff.
- **Kanban operacional:** incidentes, tickets bloqueados, ageing, tempo de resposta, mudanças emergenciais e WIP.
- **Scrum evolução:** capacidades novas, tech debt, refactoring, observabilidade, testes, definição de pronto e critérios de aceite.
- **Discovery consultivo:** coleta de requisitos, riscos, disponibilidade, segurança e FinOps; relatório com cinco iniciativas priorizadas por risco/impacto/esforço.
- **Mentoria N1/N2:** treinamento de triagem e runbooks com sinais de escalonamento e privilégios mínimos.

## Primeira aula que deve ser executada

Aula 1A sem alterações: diagnóstico local e mapeamento GKE.

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/gcp-sre/assessment-local.sh
~~~

Esse exercício **não usa gcloud, não acessa o projeto GCP e não gera cobrança**. A saída deve ser analisada para definir a Aula 1B e o dimensionamento do laboratório VirtualBox.

## Critérios para concluir esta trilha

- Diagnosticar pelo menos 3 falhas Kubernetes, identificando sintomas, hipóteses, evidências e rollback.
- Entregar um plano GCP com VPC, IAM, GKE, banco/filas, disponibilidade e segurança.
- Validar pelo menos um módulo Terraform sem realizar apply e um pipeline com testes.
- Publicar dois runbooks, um post-mortem, um assessment FinOps e um DR testado localmente.
- Justificar escolhas: GKE vs Cloud Run, SQL vs Bigtable, Pub/Sub vs fila tradicional, Standard vs Autopilot, HA vs custo.
- Apresentar um caso técnico em 30 segundos e explicar em 5 minutos sem confundir laboratório e produção.

## Links oficiais para estudo

- Google Cloud Architecture Framework: https://cloud.google.com/architecture/framework
- GKE: https://cloud.google.com/kubernetes-engine/docs
- Cloud Run: https://cloud.google.com/run/docs
- IAM: https://cloud.google.com/iam/docs
- Terraform for Google Cloud: https://cloud.google.com/docs/terraform
- Cloud Operations: https://cloud.google.com/products/operations
- Cloud SQL: https://cloud.google.com/sql/docs
- Pub/Sub: https://cloud.google.com/pubsub/docs
- Google Cloud Pricing Calculator: https://cloud.google.com/products/calculator
- FinOps Foundation: https://www.finops.org/framework/
