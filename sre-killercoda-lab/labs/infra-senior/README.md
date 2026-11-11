# Infraestrutura Sênior Híbrida — módulos de laboratório e treino oral

Base: requisitos de Analista de Infraestrutura Sênior (Hidrovias do Brasil) apresentados em duas imagens.

## O que já foi implementado
- audit-k8s.py: inventário read-only de Kubernetes (Nodes, Pods, Deployments, PVCs, NetworkPolicies, Services), capacidade solicitada e controles básicos.
- inventario-windows.ps1: inventário read-only do Windows (SO, domínio, hardware, discos, rede, serviços, funções e VMs Hyper-V se disponíveis).
- Mapa completo de lacunas e plano de estudos em docs/TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md.
- Treino de explicação técnica na documentação de entrevista, sem decorar.

**ESTES DOIS INVENTÁRIOS ESTÃO PUBLICADOS, MAS AINDA NÃO FORAM EXECUTADOS/VALIDADOS PELO USUÁRIO.**

## Primeira aula no próximo KillerCoda
1. Restaurar o laboratório com git clone e bash iniciar.sh (apenas em nova VM).
2. Validar check-observed-burn-rate.sh (já publicado antes).
3. Executar o diagnóstico Kubernetes abaixo:

    cd ~/sre-killercoda-lab
    python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py

4. Interpretar capacidade, status de Pods, solicitações de recursos e políticas. Os números de requests/limits são declarações e não consumo atual.

## Aula Windows (em máquina Windows de lab, não no KillerCoda)
Baixar/clonar o mesmo repositório e rodar com PowerShell, em ambiente autorizado:

    .\sre-killercoda-lab\labs\infra-senior\inventario-windows.ps1

Não compartilhar logs com IPs, nomes de host ou domínio corporativo sem aprovação.
Não executar como administrador por padrão; só elevar se alguma consulta permitida realmente exigir.

## Exercícios planejados (NÃO implantados por este módulo)
- Cloud compute, networking, IAM e storage Azure/AWS/GCP em sandbox com orçamento.
- Terraform, Ansible, CloudFormation e ARM/Bicep com validação segura.
- VMware/Hyper-V e storage SAN/NAS, backup, restore, RPO/RTO.
- VLAN, VPN, firewall, DNS, balanceamento, NetworkPolicy e Cilium.
- Prometheus Server/Grafana, CloudWatch/Application Insights, Dynatrace/OTel quando disponíveis.
- Segurança RBAC/IAM, governance e compliance; relatórios FinOps com custos reais.
- Migração on-prem/cloud com inventário, plano e rollback documentado.

Não instalar isso automaticamente no bootstrap de Kubernetes: recurso pequeno, custos, licenças e credenciais exigem avaliação.

## Como apresentar cada aula em entrevista
- O que é? Diga em linguagem simples.
- O que fiz? Use um caso real do laboratório ou da sua experiência profissional, identificando qual.
- O que medi? Cite comando, erro, métrica e resolução.
- Que riscos considerei? Segurança, continuidade e reversão.

Exemplo:
"Eu faço primeiro um inventário de nós e workloads, analiso capacidade solicitada e estado dos Deployments, valido armazenamento e conectividade, e só depois proponho ajustes. Em laboratório consegui detectar uma indisponibilidade Apache, restaurar o serviço e registrar falha e recuperação com métricas."

## Links
- [Roteiro completo de estudos](../../docs/TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md)
- [Treino de entrevistas](../../docs/ENTREVISTA-INFRA-SENIOR.md)

## Aula 1 concluída — diagnóstico de capacidade (11/11/2026)
Auditoria `audit-k8s.py` já executada: 2 nós, 23 Pods Running, 12 Deployments sem déficit de Ready, 2 PVC Bound; o node01 possui requests de memória 47,5% do allocatable, mas soma dos limites de memória 147,3% do allocatable. Quatro containers possuem requests incompletos e dez não possuem memory limit; não mudar configurações sem identificar workloads. NetworkPolicies padrão zero não garante ausência de políticas Cilium.

**Próximo exercício — script publicado, ainda não executado:**

    cd ~/sre-killercoda-lab
    git pull --rebase origin main
    python3 sre-killercoda-lab/labs/infra-senior/diagnostico-recursos.py

O script lista os containers problemáticos e tenta obter consumo instantâneo com `kubectl top`. Caso Metrics Server esteja ausente, relata a ausência em vez de inventar dados de uso.
