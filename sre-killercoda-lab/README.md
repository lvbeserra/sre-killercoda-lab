# SRE KillerCoda — laboratório recuperável

Laboratório prático e descartável de Linux LPIC-2, Docker, Kubernetes, Cilium/eBPF, observabilidade, Blue-Green, graceful shutdown, rolling update, SRE, segurança e FinOps.

## Por que existe

KillerCoda gratuito encerra a sessão após cerca de **1 hora** e apaga o ambiente. O GitHub preserva **a definição do laboratório** e **o histórico do curso**, não o estado da VM.

## Restaurar em um novo KillerCoda

Abra o cenário **Kubernetes** do KillerCoda (um ou dois nós, conforme o cenário), confira o contexto e execute o bootstrap abaixo. O login via navegador deve ser autorizado manualmente a cada VM descartável:

```bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
bash iniciar.sh
```

O comando `iniciar.sh` chama `sre-killercoda-lab/setup.sh`, instala `gh` quando ausente, pede autorização pelo navegador, configura o Git, executa `restore.sh` e `validate.sh` e ativa checkpoints de 50 minutos. O clone por si só não instala nem inicia nada. Se o repositório for privado, faça clone somente com autenticação segura. Não cole tokens em um terminal do KillerCoda: o ambiente é temporário e suas sessões podem registrar comandos. Para um repositório público que contém **somente estes manifests de laboratório**, o clone HTTPS é suficiente.

**Sem GitHub ainda?** Extraia este pacote e leve os arquivos para seu repositório; se `restore.sh` já estiver presente na sessão, rode `bash restore.sh`.

## Conteúdo

- `lab-completo.yaml`: namespaces; Blue (2 pods) e Green (1 pod); Service principal Blue e Service Green; ConfigMap Python de /ready e /slow; drain-demo (2 pods) com preStop 5s, SIGTERM, grace period 30s, maxUnavailable 0 e maxSurge 1; Service drain-demo.
- `setup.sh` e `../iniciar.sh`: instalador e inicializador interativo para novas sessões.
- `checkpoint.sh` e `start-checkpoints.sh`: fazem commit e push no GitHub dos arquivos permitidos e do progresso; exigem autenticação Git segura em cada VM.
- `restore.sh`: aplica tudo, aguarda rollout e verifica saúde.
- `validate.sh`: checa Service/DNS/HTTP, status de deployments e Cilium.
- `labs/cpu-benchmark-opcional.yaml`: dois Jobs de CPU. Rode **um por vez** para não contaminar a comparação.
- `docs/PROGRESSO.md`: checkpoint detalhado das aulas e próximo teste.
- `docs/GITHUB.md`: como publicar no GitHub com navegador ou Git CLI.
- `.gitignore`: impede versionamento acidental de credenciais e logs locais.

## Operação após cada aula

1. Atualize `docs/PROGRESSO.md` com *o que foi validado* e *o próximo comando*.
2. Ajuste o `lab-completo.yaml` para refletir **o estado desejado da próxima sessão**. Se fizer um patch de Kubernetes apenas no terminal, também registre a alteração no YAML; senão ela desaparece quando o cluster é destruído.
3. O monitor tentará commit/push após começar e a cada 50 minutos. Confira `/tmp/sre-checkpoints.log`, pois erros de autenticação/rede ou divergência no branch podem deixar o commit apenas na VM. Na sessão seguinte, use `git clone` e `bash iniciar.sh`.

## Limitações importantes

- Não recupera logs antigos, VMs, IPs, ClusterIPs, certificados, objetos dinâmicos, PersistentVolumes nem dados sem backup externo. Kubernetes será recriado pelo KillerCoda; o pacote restaura **aplicações**.
- Não instala Cilium, etcd, CoreDNS, kubelet, containerd ou control plane — isso vem do cenário do KillerCoda.
- Metrics Server é uma dependência **opcional** para `kubectl top`; veja `docs/METRICS-SERVER.md`. Não desativamos TLS automaticamente.
- Não inclui Secrets, service account tokens, kubeconfig, certificados, senhas ou credenciais. Nunca versionar esses arquivos.
- O laboratório é para experimentos, não um manifesto pronto para produção. As imagens não estão fixadas por digest e o container Python roda com defaults de usuário; em produção, revisar imagens, isolamento e políticas de segurança.
- Manter somente workloads leves: o cenário observado tem **1 vCPU e aproximadamente 2.2 GiB de RAM**. Não instale Istio completo sem avaliar recursos.

## Limpeza opcional

```bash
kubectl delete namespace sre-release-lab sre-cpu-lab
```

**Atenção:** isso apaga todos os recursos nesses namespaces, inclusive recursos adicionais que você tenha criado.

## Módulo opcional — Infraestrutura Sênior Híbrida
Com base na vaga Hidrovias do Brasil, foram incluídos planejamento de infraestrutura híbrida, redes, storage/backup, cloud AWS/Azure/GCP, IaC e automação, segurança, governança, observabilidade e FinOps, além de treinamento oral para entrevistas.
O módulo é **manual** e não adiciona workloads ao Kubernetes automaticamente.

- [Matriz e plano de aprendizagem](docs/TRILHA-INFRAESTRUTURA-SENIOR-HIBRIDA.md)
- [Guia de execução do módulo](labs/infra-senior/README.md)
- [Roteiro de entrevista técnica](docs/ENTREVISTA-INFRA-SENIOR.md)

Primeira tarefa opcional no KillerCoda: `python3 labs/infra-senior/audit-k8s.py`.
No Windows autorizado, usar `labs/infra-senior/inventario-windows.ps1`.
Ambos são diagnósticos read-only e **ainda não foram testados em ambiente do usuário**.


## Full Stack PostgreSQL / API / frontend — restauração automática

O módulo [labs/fullstack-postgres/README.md](labs/fullstack-postgres/README.md) já foi **validado no KillerCoda** com PostgreSQL, API e Nginx, CRUD, análise de SQL e teste controlado de lock. Agora é **restaurado e validado automaticamente com `bash iniciar.sh`**.

O setup também verifica e instala GitHub CLI (`gh`) via `apt` se necessário e solicita login seguro por navegador. Nenhum token é versionado.

Para restaurar o módulo sozinho em cluster já configurado:

    bash sre-killercoda-lab/labs/fullstack-postgres/restore-fullstack.sh
    bash sre-killercoda-lab/labs/fullstack-postgres/validate-fullstack.sh

Para executar sem Full Stack: `SRE_ENABLE_FULLSTACK=0 bash iniciar.sh`.
Para iniciar com banco e frontend, mas sem middleware: `SRE_ENABLE_MIDDLEWARE=0 bash iniciar.sh`.

**KillerCoda:** namespace, Secret, Deployments, StatefulSet e PVC são recriados, mas os incidentes não sobrevivem à destruição da sessão; o schema SQL inicia banco novo e vazio. **VirtualBox:** Kubernetes/StorageClass precisam estar instalados antes do bootstrap; disco virtual persistente e backups SQL permitirão preservar dados entre reinicializações.


## Trilha de vagas — DevOps Senior GCP / GKE

Especializacao adicional baseada nos requisitos de Analista DevOps Senior — Operacoes GCP (13/11/2026), focada em troubleshooting L3, GKE, Terraform, CI/CD, redes e IAM, FinOps, observabilidade GCP, SLIs/SLOs, DR, War Room e mentoria.

- [Plano didatico completo (8 semanas)](docs/TRILHA-GCP-DEVOPS-SENIOR-OPERACOES.md)
- [Laboratorio e comandos](labs/gcp-sre/README.md)

Primeira pratica read-only:

    bash sre-killercoda-lab/labs/gcp-sre/assessment-local.sh

**Nenhuma infraestrutura GCP e criada por essa trilha.** A integracao em nuvem depende de uma conta/projeto de testes, revisao de custos e autorizacao explicita. O modulo nao e executado pelo bootstrap padrao.


## Laboratorio de middleware Java: Apache, Tomcat e WildFly

Nova aula da trilha de infraestrutura SRE: Apache HTTP Server como proxy reverso, Tomcat para Servlet/JSP e WildFly (upstream comunitario de JBoss EAP) para Jakarta EE. Implantacao isolada no namespace sre-java-lab, sem porta publica; WildFly opcional porque exige mais RAM.

- [Guia de operacao e troubleshooting](labs/java-middleware/README.md)
- [Script de restauracao opcional](labs/java-middleware/restore-java.sh)

Execucao apos o bootstrap Kubernetes: bash sre-killercoda-lab/labs/java-middleware/restore-java.sh. Novo modulo publicado, ainda nao validado no runtime do usuario.


## Laboratorio JDBC Java (aula opcional)

Após a validação do Apache/Tomcat/WildFly e do PostgreSQL, foi publicado [labs/java-jdbc/README.md](labs/java-jdbc/README.md): novo Tomcat com WAR gerado por initContainer, JSP e driver pgJDBC 42.7.14 para fazer **SELECT somente leitura** em `srelab.incidents`, usando o Secret existente no namespace `sre-fullstack-lab`.

Não é iniciado automaticamente: para exercitar conscientemente o consumo adicional de memoria, use `bash sre-killercoda-lab/labs/java-jdbc/restore-jdbc.sh` e depois `bash sre-killercoda-lab/labs/java-jdbc/validate-jdbc.sh`. Ainda pendente de teste no KillerCoda.

O lab Java original foi **testado e validado em 13/11/2026**: Apache/Tomcat e WildFly 40.0.1 com JDK21 via imagem baseada em UBI9, compatível com os requisitos de CPU deste KillerCoda. A falha de UBI10 `Fatal glibc error: CPU does not support x86-64-v3` e sua correção estão descritas em `labs/java-middleware/README.md`.
