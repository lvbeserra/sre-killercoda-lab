# Trilha 2026 — Azure Site Recovery + Infraestrutura Híbrida Microsoft + DevOps/SRE

Fonte: três descrições de perfis de vaga fornecidas pelo usuário em 11/11/2026:
1. Especialista com forte experiência em Azure Site Recovery (ASR) e Disaster Recovery.
2. Infraestrutura/DevOps com Terraform, provisionamento, CI/CD, automação e troubleshooting de produção.
3. Suporte e administração Windows 10/11, Windows Server 2016/2019/2022, AD DS, Entra, M365, redes, VMware/Proxmox e Azure.

Objetivo: transformar esses requisitos em aulas práticas com evidências, runbooks de operação e treino para explicar em entrevistas sem decorar. Não considerar conteúdo desta trilha como experiência corporativa já comprovada.

## Priorização por aderência e dificuldade

| Prioridade | Tema | Experiência/artefato já existente | O que falta demonstrar |
|---|---|---|---|
| P0 | Azure Site Recovery / BCDR | Conhecimento Windows, Azure e Kubernetes, simulador offline DR adicionado | Exercícios reais ASR no Azure, replicação/recovery plan/failover/failback, logs, medições de RPO e RTO |
| P0 | AD DS / Windows Server / GPO / DNS / DHCP / File Server | Histórico profissional Windows/AD, scripts de inventário Windows | Consolidação de runbooks e novas práticas Windows isoladas |
| P0 | Entra ID híbrido / AD Connect / Cloud Sync / IAM | Conhecimento prévio de AD/Azure | Validar sincronização real com tenant e AD lab; configuração MFA, Conditional Access e RBAC |
| P1 | Azure Backup / Recovery Services vault | PVC e conceitos de backup e replicação; simulação ASR | Backup e RESTORE real no Azure com RPO/RTO medidos |
| P1 | VMware / Hyper-V / Proxmox / hosts físicos | Inventário Hyper-V em PowerShell preparado | VM/hipervisor de teste e ensaio de migração/recuperação |
| P1 | Azure Monitor / Log Analytics / Observabilidade | SRE Observer com SQLite, endpoint Prometheus, SLI/SLO e incidente Apache | Telemetria e alertas reais Azure, KQL e integração Dynatrace |
| P1 | Terraform / PowerShell / Azure CLI / runbooks | Bash e Python, scripts de automação; Terraform já estudado fora deste repositório | Terraform plan, módulos, state remoto seguro, validate e execução em sandbox |
| P1 | Git / CI/CD corporativo | Repositório Git, manifests declarativos, validações e checkpoints | Testes automáticos, pipeline com secrets seguro, scan, artifact, aprovação e rollback |
| P2 | Microsoft 365: OneDrive, Exchange Online, Teams, SharePoint | Conhecimento de gestão Windows/AD | Tenant de laboratório e comandos Microsoft Graph/Exchange Online com licenças/roles adequadas |
| P2 | Redes híbridas, VPN, ExpressRoute, DNS, DHCP, firewall | Cilium/eBPF, DNS Kubernetes, conectividade e scripts | Topologia on-prem/Azure, VNet, peering, roteamento, DNS híbrido, VPN/ExpressRoute em ambiente autorizado |
| P2 | Segurança: MFA, Conditional Access, Zero Trust, RBAC | Secret RabbitMQ, RBAC K8s estudado, endpoints internos | Políticas Entra avaliadas por impacto, auditoria de acessos, break-glass, least privilege |
| P2 | Windows 10/11 e hardware endpoint | Experiência em suporte e sistemas operacionais | Checklist L2/L3 de hardware/OS, Event Viewer, drivers, BitLocker, Intune quando disponível |
| P2 | Azure Storage Accounts e backups | PV/PVC do Kubernetes, SQLite local-path | Blob/file share, redundância, criptografia, restore, ciclo de vida |
| P2 | Gestão ITIL4, continuidade e mudanças | Histórico de incidentes, GMUD, acompanhamento de chamados | Runbook DR, plano de comunicação, aprovação de mudança, registro de exercício, pós-incidente |
| P2 | AWS e cloud adicional | Conhecimento e certificações AWS, laboratório K8s | Aprofundar EC2, VPC, S3 e comparação ASR vs AWS DRS |
| P2 | Times de desenvolvimento, dados e inovação | Kafka/Python Bridge/RabbitMQ, troubleshooting e testes end-to-end | Simular pipeline com testes, banco dependente e aprovações entre times |

P0 = tema mais crítico da nova vaga; P1 = complementar imediatamente; P2 = aprofundar por módulos.

## Arquitetura didática de continuidade

       Datacenter on-premises                         Azure (DR)
     +-----------------------+          +--------------------------------+
     | AD/DNS/DHCP           |          | Entra ID / Identidade / RBAC    |
     | VMware / Hyper-V      |          | Recovery Services vault        |
     | Windows Server / DB   |--ASR---->| VM replicada / Rede de DR      |
     | NAS/SAN/Backup        |          | Log Analytics / Azure Monitor  |
     +-----------------------+          +--------------------------------+
                   |                                     |
                   +----- VPN ou ExpressRoute -----------+
                                       |
                            Recovery Plan ordenado
                      rede -> banco -> aplicação -> testes
                                       |
                          RPO, RTO e evidência ITIL

Diagrama conceitual. O cluster Koda não contém esse datacenter ou a assinatura Azure com ASR: não apresentar como implementação concluída.

## Cronograma incremental, com exercícios

### Semana 1 — ASR e arquitetura BCDR
- Comparar Azure Backup, ASR, Recovery Services vault, Storage Account e failover.
- Aprender origem/destino e diferenças A2A, VMware/Hyper-V/físico.
- Executar o simulador offline de 3 cenários e explicar RPO/RTO com números.
- Produzir um plano de recuperação com dependências de AD/DNS, banco e aplicação.
- Revisar failback: reprotect, sincronização, mudança de DNS e reconciliação de dados.

### Semana 2 — Windows Server e identidade híbrida
- AD DS, FSMO, DNS, DHCP, Netlogon, GPO, DFS/File Server e troubleshooting replicação.
- Entra Connect Sync vs Cloud Sync (escolha depende dos requisitos da topologia, objetos e funcionalidades).
- IAM, MFA, Conditional Access, Zero Trust, RBAC e cenários de indisponibilidade do AD.
- Onboarding/offboarding de usuários e sincronização para M365 (com tenant de teste).
- Treino oral: explicar o diagnóstico de logon, falha DNS e recuperação sem discurso memorizado.

### Semana 3 — Automação, IaC e CI/CD
- Terraform: providers, plan, state, modules, import, drift, backend e locking.
- Azure CLI e PowerShell: consulta read-only, scripts testáveis e idempotentes; runbooks.
- GitHub Actions / Azure DevOps: testes unitários, validação Terraform, aprovação e rollback.
- Estruturar um projeto com políticas de código, segredos fora do Git e evidência CI.
- Diferenciar execução em laboratório de alterações de produção.

### Semana 4 — Operação, observabilidade e prova final
- Azure Monitor e Log Analytics/KQL para health, failover jobs, logs e replicação.
- Segurança de rede de DR: VPN/ExpressRoute, VNet/Subnet, DNS, Firewall/NSG.
- FinOps: custo de proteção, retenção, storage, tráfego e ambiente ativado para testes.
- Simular game day de continuidade e elaborar postmortem com cronologia e plano de ação.
- Apresentar a solução a gestor em 60 segundos e a arquiteto em 3 minutos.

## Runbook de DR de uma aplicação com banco

**Antes:** responsável de negócio aprova RPO/RTO; inventário origem, dependências, credenciais, backup e testes; contato do incidente e plano de comunicação.

**Teste:** definir VNet isolada, selecionar ponto consistente, iniciar Test Failover aprovado, levantar banco antes do app, validar DNS/autenticação, testar fluxos críticos, registrar logs, RPO e RTO observados, concluir Cleanup Test Failover.

**Desastre real:** confirmar severidade, obter aprovação de autoridade responsável, escolher recovery point disponível, executar recuperação na região/ambiente alternativo, validar integridade e serviço, registrar decisão de commit, comunicar stakeholders.

**Volta:** confirmar estabilidade da origem, habilitar reprotect, sincronizar mudanças do ambiente DR, executar failback planejado, validar consistência, reestabelecer monitoramento e proteção.

Não executar automaticamente esses procedimentos em produção. Cada mecanismo e ordem exata dependem da plataforma, tipo de VM e arquitetura.

## Distinções fundamentais para entrevista
- **Backup vs Disaster Recovery:** backup restaura dados; DR mantém/recupera operação de serviços e dependências em ambiente alternativo.
- **RPO vs RTO:** tolerância temporal para perda de dados vs prazo de retomada do serviço.
- **Teste vs failover real:** Test Failover em rede isolada não equivale a alterar produção.
- **Failover vs failback:** mudar operação ao destino vs retornar à origem após sincronizar/proteger.
- **AD DS vs Entra ID:** diretório local e serviços do domínio vs plataforma de identidade cloud; integração precisa de sincronização/controlos.
- **Connect Sync vs Cloud Sync:** tecnologias de sincronização com capacidades e limites distintos; escolher conforme documentação atual e cenário.
- **IaC vs script:** Terraform mantém estado declarativo e faz plano; PowerShell/Bash automatizam operações e processos.
- **Monitoring vs DR:** detectar indisponibilidade é diferente de já ter plano e capacidade validada para recuperar serviços.

## Fala treinável em 30 segundos (após prática offline)
"Minha experiência principal é sustentação e troubleshooting de infraestrutura Windows/AD e monitoramento. Estou aprofundando Disaster Recovery no Azure e infraestrutura híbrida com um laboratório próprio. Nele estudo RPO/RTO, planos de recuperação, integração de aplicações e automação; começo por simulações seguras e avanço para exercícios reais somente em ambiente autorizado. Meu foco é recuperar serviços com evidências e diminuir o risco operacional."

Não dizer "implantei Azure Site Recovery em produção" ou "domino GCP/Proxmox" sem experiência real.

## Limites e pré-requisitos
- KillerCoda não oferece Windows/Hyper-V/VMware/Proxmox, tenant Microsoft 365 ou assinatura com ASR.
- Para ASR real: permissão de assinatura/sandbox, custo autorizado, topologia e compatibilidade validadas, recursos adequados.
- Entra ID e M365 podem exigir tenant, domínio, licenças e papéis administrativos.
- As verificações do laboratório atual são sintéticas e não validam RPO/RTO do Azure.
- Windows 10/11 e suporte de hardware precisam de uma máquina Windows de teste, não do terminal Linux KillerCoda.

## Referências oficiais
- https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-overview
- https://learn.microsoft.com/en-us/azure/reliability/reliability-site-recovery
- https://learn.microsoft.com/en-us/azure/site-recovery/recovery-plan-overview
- https://learn.microsoft.com/en-us/azure/site-recovery/failover-failback-overview-modernized
- https://learn.microsoft.com/en-us/azure/site-recovery/monitor-site-recovery
- https://learn.microsoft.com/en-us/azure/site-recovery/monitor-log-analytics
- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/connect-to-cloud-sync-decision-guide

## Próxima execução
Sem alterar estado de Kubernetes:

    cd ~/sre-killercoda-lab
    git pull --rebase origin main
    python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py

Depois explorar o módulo AD/Entra, IaC e M365 em labs adequados, um assunto de cada vez.
