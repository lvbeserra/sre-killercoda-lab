# SRE KillerCoda Lab — entrada rápida

Lab Kubernetes/SRE reproduzível, com Blue-Green, rolling updates, Cilium/eBPF, HTTP e checkpoints Git.

## A cada sessão nova do KillerCoda

No terminal Ubuntu do cenário Kubernetes:

```bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
bash iniciar.sh
```

**O `iniciar.sh` automatiza o setup completo:** verifica Kubernetes, instala automaticamente o GitHub CLI (`gh`) por `apt` se estiver ausente, autentica por dispositivo no navegador, configura o Git local, restaura Blue/Green, PostgreSQL, API Python, Nginx, Apache/Kafka/RabbitMQ e valida o Full Stack. Também inicia checkpoints Git a cada **50 minutos**. Não reinstala `gh` quando já existe.

O `git clone` sozinho **não instala softwares nem executa scripts**. Execute `bash iniciar.sh` em cada nova VM. Como a VM é descartável, o login do GitHub também precisará ser autorizado novamente.

**Importante:** salve no manifesto qualquer alteração feita apenas via `kubectl`; checkpoints versionam arquivos Git e uma captura de status, não o estado completo da VM ou do cluster. Veja [documentação detalhada](sre-killercoda-lab/README.md) e [progresso das aulas](sre-killercoda-lab/docs/PROGRESSO.md).

### Verificar os checkpoints
```bash
tail -30 /tmp/sre-checkpoints.log
git status -sb
```

Um `git push` só está confirmado quando o log diz `SUCESSO: checkpoint publicado no GitHub.`. Se houver falha de rede, autenticação ou conflito Git, o checkpoint poderá ficar só na VM.

Não envie credenciais, kubeconfig, Secrets ou tokens ao GitHub. O Metrics Server é opcional e não é instalado por padrão por exigir avaliação do TLS do kubelet neste lab.

## Novo módulo: Apache + Kafka + RabbitMQ
O `bash iniciar.sh` agora também implanta por padrão o namespace `sre-middleware-lab`: Apache HTTP Server, Kafka em KRaft standalone e RabbitMQ Management. A senha RabbitMQ é gerada no cluster e não é comitada. O projeto de eventos de pagamento é **simulado** (sem dados reais). Teste: `bash sre-killercoda-lab/labs/validate-middleware.sh`.

Os limites de memória somados podem ultrapassar a capacidade de cenários KillerCoda pequenos. Para subir apenas o laboratório Blue/Green em máquinas limitadas: `SRE_ENABLE_MIDDLEWARE=0 bash iniciar.sh`. Os volumes de Kafka/RabbitMQ são `emptyDir`, não preservam filas/mensagens entre sessões.

Existe alternativa `sre-killercoda-lab/labs/docker-compose.middleware.yaml` para ambientes Docker locais; use arquivo de ambiente local `sre-killercoda-lab/labs/.env.middleware` com `RABBITMQ_DEFAULT_USER=labuser` e `RABBITMQ_DEFAULT_PASS` forte. **Não versionar esse arquivo.**

**Dynatrace:** instruções de integração opcional em [docs/DYNATRACE.md](sre-killercoda-lab/docs/DYNATRACE.md). Requer conta Dynatrace e credenciais por sessão; não é instalado nem monitora automaticamente por causa dos pré-requisitos, segurança e capacidade do cluster.

## Trilha Infraestrutura Sênior Híbrida (nova)
Os requisitos da vaga de Analista de Infraestrutura Sênior (Hidrovias do Brasil) foram incorporados à trilha de estudos, com módulos de Windows/AD/Hyper-V, cloud AWS/Azure/GCP, IaC, redes, storage/backup, observabilidade, segurança, FinOps e migração.
A expansão é **opcional e sob demanda**; não implanta automaticamente ambientes Windows/cloud nem gera cobranças.

- [Plano completo e matriz da vaga](sre-killercoda-lab/docs/TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md)
- [Primeiros diagnósticos read-only Kubernetes/Windows](sre-killercoda-lab/labs/infra-senior/README.md)
- [Treino de explicação técnica para entrevistas](sre-killercoda-lab/docs/ENTREVISTA-INFRA-SENIOR.md)

Na próxima sessão KillerCoda, depois de restaurar o ambiente e validar o burn rate observado:
```bash
python3 sre-killercoda-lab/labs/infra-senior/audit-k8s.py
```
O script e a coleta PowerShell ainda aguardam execução/validação prática pelo usuário.


## Nova trilha: Azure Site Recovery, AD híbrido, Microsoft 365 e DevOps (11/11/2026)

Requisitos de novas vagas incorporados ao curso. Priorização: Azure Site Recovery/DR, RPO-RTO, Recovery Plans, failover/failback; Windows Server/AD/Entra; M365; Azure Backup, rede, Hyper-V/VMware/Proxmox, IaC Terraform, CI/CD, segurança e observabilidade.

- [Roteiro completo, cronograma e matriz](sre-killercoda-lab/docs/TRILHA-DR-ASR-AD-M365-DEVOPS.md)
- [Módulo Azure Site Recovery e BCDR](sre-killercoda-lab/labs/dr-azure/README.md)

**Primeiro laboratório de DR (somente simulação offline, sem Azure ou VM real):**
```bash
python3 sre-killercoda-lab/labs/dr-azure/simular-dr.py
```

O código foi publicado, porém não foi executado pelo usuário no KillerCoda. Nenhum recurso Azure foi provisionado; nenhuma VM replicada. O novo módulo não altera o bootstrap padrão.


## PostgreSQL + API + Frontend incluídos no bootstrap padrão (12/11/2026)

O laboratório **Full Stack de incidentes SRE** já foi executado e validado em Kubernetes: PostgreSQL 17 com PVC, API REST Python/Psycopg e frontend HTML/JS em Nginx. Agora o comando `bash iniciar.sh` **instala e valida esse módulo automaticamente** no namespace `sre-fullstack-lab`.

- [Guia do módulo Full Stack](sre-killercoda-lab/labs/fullstack-postgres/README.md)
- [Manifestos Kubernetes](sre-killercoda-lab/labs/fullstack-postgres/resources.yaml)
- [Histórico das aulas](sre-killercoda-lab/docs/PROGRESSO.md)

Em uma **nova sessão KillerCoda**:

```bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
bash iniciar.sh
```

Não é necessário executar `restore-fullstack.sh` separadamente. Opcionalmente:

```bash
SRE_ENABLE_MIDDLEWARE=0 bash iniciar.sh  # mantém PostgreSQL, API e Nginx
SRE_ENABLE_FULLSTACK=0 bash iniciar.sh   # pula o Full Stack
```

**GitHub CLI:** instalação automática quando necessário em Ubuntu/Debian com `apt-get`. Sessão descartável pede novo login; em VirtualBox, disco persistente conserva o binário instalado.

**Persistência:** o GitHub armazena scripts, manifests, schema SQL e anotações, **não** os dados do PostgreSQL. Em nova sessão descartável, o banco será criado com schema vazio. Dados persistentes exigem backup SQL ou volume em disco durável. Nunca versionar credenciais e dumps com dados sensíveis.

**VirtualBox:** requer uma VM com Linux, Kubernetes e armazenamento persistente previamente instalados; `iniciar.sh` restaura workloads no Kubernetes, mas não instala o cluster.


## Nova trilha: DevOps Senior — Operacoes GCP / GKE (13/11/2026)

A partir de uma vaga de DevOps Senior GCP, o curso agora inclui um roteiro de **8 semanas**: GCP/IAM/VPC, GKE, Terraform, GitHub Actions/Cloud Build/ArgoCD, observabilidade/SLOs, Cloud SQL/Bigtable/PubSub, FinOps/DevSecOps, disaster recovery e War Rooms P1 com post-mortems e mentoria.

- [Trilha completa GCP](sre-killercoda-lab/docs/TRILHA-GCP-DEVOPS-SENIOR-OPERACOES.md)
- [Guia do modulo e primeira pratica](sre-killercoda-lab/labs/gcp-sre/README.md)
- [Script de assessment Kubernetes read-only](sre-killercoda-lab/labs/gcp-sre/assessment-local.sh)

Primeira aula, **sem provisionar recursos GCP**:

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/gcp-sre/assessment-local.sh
~~~

A trilha GCP e opcional e **nao altera o iniciar.sh**: nenhum projeto GCP, GKE, Cloud SQL ou recurso faturavel sera criado automaticamente. O roteiro e o script foram publicados, mas o novo assessment ainda precisa ser executado pelo usuario.
