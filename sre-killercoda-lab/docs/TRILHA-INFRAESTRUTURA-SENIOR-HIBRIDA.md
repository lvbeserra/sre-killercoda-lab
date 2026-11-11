# Trilha Infraestrutura Sênior Híbrida — requisitos da vaga Hidrovias do Brasil

Fonte: imagens da descrição da vaga "Analista de Infraestrutura Sênior" compartilhadas pelo usuário.
Escopo: roteiro educacional + experimentos; não representa experiência profissional já obtida em todas as tecnologias.
Documentado: 10/11/2026.

## Objetivo
Complementar o laboratório Kubernetes/SRE com conhecimentos demonstráveis de ambientes híbridos (on-premises + cloud), storage, redes, IaC, governança, observabilidade e FinOps. Em cada capítulo produzir:
1. Um desenho de arquitetura e analogia.
2. Um diagnóstico técnico reproduzível, com comandos e saídas.
3. Uma mudança declarativa ou procedimento controlado, quando possível.
4. Evidências de validação e rollback, sem dados corporativos sensíveis.
5. Uma explicação de 20, 40 e 90 segundos para gestores/entrevista.

## Matriz de aderência fiel à vaga

| Requisito do anúncio | Já desenvolvido no SRE KillerCoda | Novo exercício / lacuna |
|---|---|---|
| Servidores físicos, virtuais, storage e cloud híbrida | Linux K8s 2 nós, volumes PVC, práticas anteriores de Hyper-V/Windows | Inventário Windows/Hyper-V, desenho de integração on-prem ↔ nuvem; SAN/NAS e backup em laboratório compatível |
| Azure, AWS, GCP: compute, storage, network, identity, security | Conhecimentos e labs pessoais anteriores de AWS/Azure; K8s local neste repo | Módulos seguros separados para cada provedor; GCP apenas planejado |
| VMware / Hyper-V | Inventário PowerShell adicionado, não validado no Koda | Laboratório em hipervisor disponível, checkpoints/snapshots e capacidade |
| SAN/NAS, backup | PVC local-path, mas sem backup persistente validado | NFS/NAS, RPO/RTO, backup, restore e teste de integridade |
| Rede/VPN/firewall/VLAN/load balancer | DNS Service, Cilium/eBPF e endpoints | Diagramas L2/L3, ACL, firewall, LB, simulação segmentação e diagnóstico |
| Terraform, Ansible, ARM, CloudFormation | Kubernetes YAML declarativo e scripts Bash/Python | Exemplos IaC opcionais e planos de validação sem deployment automático/conta |
| PowerShell/Bash/Python | Bash/Python reais; novo inventário PowerShell de Windows | Automação com testes e logs estruturados, revisão de segurança |
| Observabilidade CloudWatch, Application Insights, Dynatrace, Grafana, Prometheus | Endpoint Prometheus/metrics, collector SQLite, probes e alertas sintéticos | Integrações cloud e Dynatrace ainda não implantadas; Grafana/Prometheus server conforme capacidade |
| Identidade, governança, compliance | Secret RabbitMQ sem commit, namespace, automount token false em algumas apps | RBAC, autenticação/SSO, menor privilégio, políticas e auditoria |
| Incidentes complexos/performance | CPU limits, rollout/graceful shutdown, consumer recovery, idempotência, DLQ, SLI/SLO | Runbooks, game days, postmortem, observabilidade fora do cluster |
| Migração e integração on-prem/cloud | Apps containerizadas e manifests recuperáveis | Plano de migração: assessment, dependências, DNS, conectividade, rollback, RTO/RPO |
| FinOps: relatórios e melhorias | Inspeção de requests/limits já debatida | Auditoria read-only Kubernetes e depois custo real por recurso/cloud |

**Formação superior completa:** requisito da vaga, não é uma tecnologia e deve ser verificado no currículo do candidato; este laboratório não comprova titulação acadêmica.

## Arquitetura corporativa didática alvo

    USUÁRIO / EMPRESA
          |
    [Identidade AD/Entra ID / IAM] <--- políticas, RBAC, MFA
          |
    On-premises -------------------- VPN/Link privado ------------------ Cloud
    Windows + Hyper-V/VMware                                      Azure/AWS/GCP
    Servidores + SAN/NAS                                           VMs/VPC/VNet/Storage
          \                                                           /
           \--> Git / IaC / Pipeline de mudança <-------------------/
                          |
                    Kubernetes
        Apache -> Kafka -> Bridge -> RabbitMQ -> Worker
                          |
                   Observabilidade
           métricas / logs / traces / SLI / SLO
                          |
                   Auditoria e FinOps

A topologia acima é PROPOSTA DIDÁTICA; nem todas as caixas foram provisionadas.

## Módulos e ordem recomendada

### Módulo A — Inventário e operação híbrida [PRIMEIRO]
Prática no Kubernetes descartável:

    cd ~/sre-killercoda-lab
    python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py

O script faz somente leituras de Nodes/Pods/Deployments/Services/PVCs/NetworkPolicies.
Calcular requests vs allocatable não equivale a CPU/RAM consumida nem a custos financeiros.

**No Windows Server AUTORIZADO** (não é compatível com KillerCoda Linux):

    powershell -NoProfile -File .\sre-killercoda-lab\labs\infra-senior\inventario-windows.ps1

Saídas esperadas: inventário, disponibilidade, capacidade e hipóteses de risco.
Evidência: resultado limpo sem IP, host ou domínio corporativo publicados.

### Módulo B — Redes e storage
Revisar TCP/IP, DNS, VLAN, subnet, roteamento, NAT, ACL, VPN, load balancing, SAN vs NAS vs object storage, RPO/RTO.
Prática futura: namespaces cliente/backend, NetworkPolicy em laboratório, falhas de DNS e NFS, snapshot/restore. Confirmar NetworkPolicy antes de aplicar para não quebrar bridge ou observer.
Analogia: VLAN/NetworkPolicy são portarias; DNS é catálogo de endereços; Load Balancer é distribuidor de atendimento; SAN/NAS são formatos diferentes de armazenamento.

### Módulo C — IaC, cloud e automação
Terraform: plano declarativo e controle de estado; Ansible: execução de tarefas e configuração; CloudFormation/ARM: templates nativos; scripts: operações específicas e automação.
Prática futura: validar templates offline, plan sem credenciais de produção, revisar diffs, aplicar somente em conta sandbox com orçamento e aprovação. AWS/Azure primeiro, GCP na sequência.
Não implantar recursos pagos nem registrar secrets/tokens neste repositório.

### Módulo D — Observabilidade, confiabilidade e incidentes
Aproveitar /metrics e SQLite do Worker; concluir check-observed-burn-rate.sh e depois pipeline de telemetria persistente. CloudWatch/Application Insights/Dynatrace/Grafana são destinos futuros, a depender de acesso/recursos.
Evidências existentes: 120/120 consultas HTTP num rollout, Worker ACK após retomar, DLQ, duplicatas ignoradas, incidente Apache com SLI amostral de 84,615%. Não afirmar SLO mensal.

### Módulo E — Segurança, governança e compliance
Identidade AD DS, Entra ID/IAM, MFA, grupos, RBAC, segredos, hardening, aprovação de mudanças, auditoria e políticas.
Laboratório: examinar RBAC com kubectl auth can-i (apenas contas autorizadas), criar NetworkPolicy em namespace isolado, scanner de imagens quando disponível.
Não testar credenciais corporativas no KillerCoda público.

### Módulo F — FinOps e capacidade
1. Inventariar recursos, requests e limits no cluster (novo script).
2. Medir CPU/memória efetiva com API de métricas quando disponível.
3. Comparar dimensionamento, reservas e capacidade.
4. Em cloud sandbox, obter custos reais de billing e estimar cenários; gerar relatório de redução de desperdício, compromisso de gasto e tags obrigatórias.
Nunca inventar economia a partir de Kubernetes requests.

### Módulo G — Migração on-premises → cloud
Elaborar arquitetura de origem/destino, inventário de dependências, conectividade e identidade; testar banco, DNS, backup/restore, cutover e rollback; definir critérios de aceite.
Somente migrar cargas reais com aprovação, backups testados e plano reversível.

## Como desenvolver a comunicação técnica sem decorar
Memória curta por tecnologia:
- O que é? (uma frase, ex.: Kubernetes mantém as réplicas e coordena deploys).
- Quando usei? (uma experiência real, ex.: restaurar serviço Apache durante incidente simulado).
- Qual evidência? (ex.: o probe retornou success=0 e depois success=1).

Script de 20 segundos:
"Começo pelo impacto e pela hipótese. Valido serviços, conectividade e logs.
Depois intervenho de forma controlada, confirmo a recuperação e registro evidências."

Script de 40 segundos para vaga:
"Minha base é infraestrutura e resolução de incidentes em ambientes Windows/AD e monitoramento.
Tenho experiência prática em análise de disponibilidade, servidores e automação;
também desenvolvo um laboratório Kubernetes/SRE em que valido deploys, mensageria,
tratamento de falhas e observabilidade. Minha abordagem é diagnosticar com evidências,
agir com segurança e documentar o resultado."

**Não confundir prática de laboratório com experiência em produção.**
Treinar primeiro sozinho, depois com perguntas previsíveis e finalmente com entrevistas.

## Critério de conclusão por tecnologia
- Explica com analogia em uma frase.
- Executa o diagnóstico sem copiar comando aleatório.
- Apresenta evidência de teste e explica limites.
- Conhece impacto, rollback e segurança.
- Comunica o caso em até 60 segundos, sem decorar a ordem exata das palavras.

## Prioridade para a próxima sessão KillerCoda
1. Recuperar bash iniciar.sh em cluster Kubernetes novo.
2. Verificar Pods e PVC; lembrar que histórico de SQLite/emptyDir anterior não volta.
3. Validar bash sre-killercoda-lab/labs/check-observed-burn-rate.sh.
4. Rodar python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py.
5. Selecionar UM próximo módulo para implementação aprofundada; não iniciar tudo ao mesmo tempo.

## Referências internas
- [Histórico de testes](PROGRESSO.md)
- [Apresentação para gestores](APRESENTACAO-GESTORES-E-GUIA-ESTUDO.md)
- [Readme do módulo](../labs/infra-senior/README.md)


## Extensão prioritária — Azure Site Recovery, AD híbrido, M365 e CI/CD

Foram adicionados requisitos de continuidade de serviços e Azure Site Recovery (ASR): Azure Backup, Recovery Services vault, replicação de VMware/Hyper-V/físicos, A2A, Recovery Plans, Test/Planned/Unplanned Failover, Failback, RPO/RTO, Azure Monitor/Log Analytics, VPN/ExpressRoute, Entra ID, RBAC, runbooks PowerShell/CLI, ITIL4, Terraform/CI-CD; além de Windows Server 2016/2019/2022, AD DS, Connect Sync/Cloud Sync, Microsoft 365, MFA/Conditional Access, endpoints Windows 10/11 e Proxmox.

- [Plano completo e escopo das novas vagas](TRILHA-DR-ASR-AD-M365-DEVOPS.md).
- [Módulo DR offline e roteiro para ASR real](../labs/dr-azure/README.md).
- O simulador DR é conceitual, **não** Azure Site Recovery real; a futura fase com cloud exigirá assinatura sandbox, acesso e aprovação de custos.
