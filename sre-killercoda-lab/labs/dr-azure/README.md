# Azure Site Recovery / Disaster Recovery — novo laboratório

Criado a partir dos requisitos de vagas de Infraestrutura Sênior compartilhados em 11/11/2026.
**Estado real:** módulo de estudo + simulador OFFLINE publicados. Nenhuma VM foi replicada no Azure, nenhuma assinatura configurada, nenhum teste de failover ASR real executado.

## Primeiro laboratório agora, sem conta cloud

A partir do clone:

    python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py

Para selecionar apenas uma hipótese:

    python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py --scenario unplanned

Autoteste do simulador:

    python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py --self-test

O modelo usa relógio virtual e cinco eventos fictícios. Ele **não controla VMs, Kubernetes, redes ou recursos Azure**.

### Resultados previstos do modelo
- Test Failover: cópia simulada isolada de 3 eventos, sem interromper a origem e sem alterar rotas de produção; limpa a cópia fictícia.
- Planned Failover: bloqueia novas escritas no modelo, faz sincronização final; ponto de replicação na hora da troca, RPO=0 s e RTO=50 s virtuais.
- Unplanned Failover: falha no instante virtual 150 s; checkpoint na marca 90 s; idade de recovery point=60 s e 2 eventos sem replicação. Detecção 50 s + plano de recuperação 50 s = RTO=100 s virtuais.
- Com metas didáticas RPO de 30 s e RTO de 120 s, unplanned falha no RPO e atende ao RTO no modelo.
- Failback: dados novos surgidos no ambiente DR são sincronizados na volta, mas eventos não replicados antes do desastre não ressurgem magicamente; requer reconciliação.

**Importante:** duração virtual e idade do checkpoint não são métricas reais do ASR nem medem exatamente a perda de transações de uma aplicação.

## Conceitos: diferença entre serviços

Azure Site Recovery (ASR) mantém replicação e orquestra failover/failback de cargas suportadas, como Azure-to-Azure, VMware-to-Azure, Hyper-V-to-Azure e físico-to-Azure, sujeito à compatibilidade do cenário.

Azure Backup mantém pontos restauráveis segundo regras de backup e retenção. Não equivale ao failover orquestrado de uma VM pelo ASR. Recovery Services vault centraliza gerenciamento de recuperação para ambos, mas o Vault usado pelo Site Recovery guarda CONFIGURAÇÕES de replicação, não os discos replicados em si.

Analogia:
- Backup = arquivo de cópias para recuperação.
- ASR = plano e capacidade de continuar operando em um ambiente alternativo.
- Recovery Plan = roteiro ordenado de dependências, com runbooks e checagens.
- RPO = quanto tempo de alterações é tolerável perder.
- RTO = quanto tempo o serviço pode demorar para voltar.

## Procedimento de estudo para um ASR corporativo (NÃO executar sem autorização)

1. Inventariar VMs, discos, OS, aplicações, dependências de AD/DNS/banco, churn, rede e serviços.
2. Acordar RPO/RTO por aplicação e identificar dono da continuidade.
3. Selecionar a topologia: VMware, Hyper-V, físico ou Azure-to-Azure, destino e recovery networking; verificar limitações atuais por cenário.
4. Preparar identidade e RBAC, rede, cache/storage, regiões e Recovery Services vault; acompanhar replicação e recovery points.
5. Criar Recovery Plan com grupos ordenados: identidade/DNS -> rede -> storage -> banco -> aplicação -> validação.
6. Executar Test Failover em rede ISOLADA, com teste funcional e cleanup explícito, preservando a origem.
7. Em incidente real aprovado, selecionar recovery point, realizar failover, validar serviços e efetuar commit apropriado.
8. Na volta, reprotect, sincronizar retorno, executar failback planejado e validar consistência e reativação da proteção.
9. Monitorar replication health, RPO, jobs, test failovers, logs no Azure Monitor/Log Analytics; documentar testes e mudanças via ITIL.

Os detalhes de Planned Failover variam entre cenários VMware/Hyper-V/A2A; nunca pressupor que todos sejam idênticos.

## Opcional: inventário Azure read-only

Somente em conta Azure sandbox autorizada, com CLI previamente instalada e autenticada:

    bash sre-killercoda-lab/labs/dr-azure/inventario-azure-readonly.sh

Consulta vaults e workspaces sem alterar recursos. A saída pode conter nomes internos; não publicar. NÃO executar como prova de ASR em produção.

## Perguntas orais simples
- Para que serve ASR? Replicar cargas e orquestrar sua recuperação em um ambiente alternativo.
- Backup e ASR são iguais? Não. Backup oferece pontos de restauração; ASR coordena continuidade/failover.
- O que é RPO? Período máximo tolerado de perda de alterações.
- O que é RTO? Tempo máximo tolerado para reestabelecer o serviço.
- O que Test Failover prova? Se as dependências sobem e a aplicação funciona em uma rede de teste sem interferir na operação normal.
- Qual o risco do failback? Divergência de dados, reconfiguração incompleta e retorno antes de garantir replicação consistente.

## Recursos e limitações
- O KillerCoda não fornece assinatura Azure para ASR, VMware nem Windows Server.
- Simulador e inventário não alteram produção e não criam VMs.
- Azure real pode gerar custos de replicação, armazenamento, VMs durante testes, logs e tráfego.
- Nunca implantar ou disparar failover de ASR em ambiente corporativo sem aprovação e plano de mudança.

## Microsoft Learn (consultadas em novembro de 2026)
- https://learn.microsoft.com/en-us/azure/site-recovery/site-recovery-overview
- https://learn.microsoft.com/en-us/azure/reliability/reliability-site-recovery
- https://learn.microsoft.com/en-us/azure/site-recovery/failover-failback-overview-modernized
- https://learn.microsoft.com/en-us/azure/site-recovery/hyper-v-azure-architecture
- https://learn.microsoft.com/en-us/azure/site-recovery/vmware-azure-architecture
- https://learn.microsoft.com/en-us/azure/site-recovery/recovery-plan-overview
- https://learn.microsoft.com/en-us/azure/site-recovery/monitor-site-recovery
