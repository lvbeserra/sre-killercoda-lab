# Laboratório de DevOps Sênior — GCP / GKE / SRE

Este laboratório acompanha a [Trilha DevOps Sênior Operações GCP](../../docs/TRILHA-GCP-DEVOPS-SENIOR-OPERACOES.md), criada a partir de uma vaga fornecida pelo estudante em 13/11/2026.

## O que está pronto hoje

- **Aula 1A:** script de avaliação e troubleshooting de Kubernetes local, sem alterações em recursos e sem custo de nuvem: [assessment-local.sh](assessment-local.sh).
- **Conteúdo estruturado:** plano em oito semanas cobrindo GCP, GKE, Terraform, CI/CD, Observabilidade, SLI/SLO, FinOps, IAM/DevSecOps, bancos e mensageria, DR, liderança de War Room e mentoria.
- **Base do curso existente:** Full Stack PostgreSQL/API Python/Nginx, middleware Kafka/RabbitMQ, Blue/Green e testes de incidentes; reaproveitada para cenários similares ao GKE.
- **Não feito:** nenhum projeto, cluster GKE, Cloud SQL ou recurso GCP foi provisionado; não foi executado esse novo script no cluster ainda.

## Executar a primeira aula

No KillerCoda já iniciado:

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/gcp-sre/assessment-local.sh
~~~

Em uma VM VirtualBox futura, instalar antes Ubuntu + Kubernetes (por exemplo, K3s) e kubectl. O script apenas consulta o cluster atual.

## Interpretação

Preencha um registro de incidente:

| Campo | Pergunta |
|---|---|
| Contexto | Qual cluster e namespace estamos investigando? |
| Impacto | Qual usuário/serviço estaria afetado? |
| Evidência | Quais Pods, Nodes, PVCs, métricas e permissões mostram o sintoma? |
| Hipóteses | Agendamento, configuração, rede, storage ou dependência? |
| Causa raiz | Quais evidências confirmariam ou descartariam as hipóteses? |
| Mitigação | Qual ação de menor risco e qual rollback? |
| Prevenção | Probe, request/limit, HPA, alertas, runbook ou automação? |

**Próximo exercício:** criar incidente controlado de Pod Pending ou readiness, comparar com o modelo GKE e produzir runbook de resposta. Não executar scripts destrutivos sem isolamento explícito.

## Regras de segurança e custo

A Aula 1A não executa gcloud e não cria cobranças. Para GCP real, serão exigidos projeto isolado, entendimento do faturamento, autorização do estudante, cálculo de custos, quotas, cleanup e plano de rollback. Não enviar credenciais nem chaves JSON ao GitHub. O iniciante não precisa de conta paga para concluir as primeiras atividades.

Para iniciar o laboratório **geral** do curso (sem provisionar GCP):

~~~bash
bash iniciar.sh
~~~

Esse bootstrap instala GitHub CLI quando falta, autentica quando necessário e restaura Full Stack, Kubernetes e middleware local. GCP é uma trilha de ensino opcional, não uma dependência obrigatória.
