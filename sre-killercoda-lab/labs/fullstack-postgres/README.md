# Laboratório Full Stack: PostgreSQL + backend Python + frontend web

**Status:** código e manifests publicados no GitHub; instalação/execução no KillerCoda ainda precisa ser validada pelo usuário.

## O que vamos construir
- Namespace Kubernetes sre-fullstack-lab.
- PostgreSQL 17 Alpine com StatefulSet de uma réplica, PVC 1 GiB e credenciais aleatórias em Secret.
- API Python 3.12 com Psycopg 3 fixado na versão 3.2.10, SQL parametrizado e rotas para criar, listar e atualizar incidentes.
- Frontend HTML/CSS/JavaScript servido por Nginx, com proxy de API na mesma origem.
- Endpoints: /healthz, /readyz, /api/health, /api/incidents, /api/slow?ms=2000 e /metrics.

**Não** está integrado ao Apache/Kafka/RabbitMQ automaticamente. Sem autenticação, TLS, backup externo ou HA; usar somente dados e ambientes de laboratório. Não expor publicamente na Internet.

## Instalar no KillerCoda (manual e opcional)

No terminal do cenário Kubernetes:

    cd ~/sre-killercoda-lab
    git pull --rebase origin main
    bash sre-killercoda-lab/labs/fullstack-postgres/restore-fullstack.sh

O script aplica namespace, cria Secret com senha randômica se não existir, monta schema e código em ConfigMaps e aplica StatefulSet, Deployments e Services. Não altera os outros namespaces.

**A primeira instalação da API faz pip install via PyPI** no container e exige conectividade de saída. Em produção, use imagem imutável criada/testada em CI, não instalações dinâmicas de pacotes.

PostgreSQL executa schema.sql apenas quando seu diretório de dados está VAZIO. Para evoluir um banco existente, usar migrações versionadas.

## Validar

    kubectl -n sre-fullstack-lab get pods,svc,pvc -o wide
    bash sre-killercoda-lab/labs/fullstack-postgres/validate-fullstack.sh

A validação faz somente leituras SQL e endpoints.
Para testar escrita e atualização de um incidente FICTÍCIO:

    bash sre-killercoda-lab/labs/fullstack-postgres/test-incident-flow.sh

Esse segundo script **cria um registro** no PostgreSQL e atualiza seu status.

## Abrir frontend

Em terminal separado:

    kubectl -n sre-fullstack-lab port-forward svc/incidents-web 8080:80

Acesso local: http://localhost:8080 . No KillerCoda, verifique se a função de visualização de portas da sessão pode abrir a porta 8080. Algumas sessões precisam de port-forward com --address 0.0.0.0 para o preview; só faça isso em laboratório isolado, pois a aplicação não possui autenticação.

Se o navegador não abrir, execute os testes via terminal, que já percorrem Nginx, API e PostgreSQL.

## Investigar incidentes SRE

    kubectl -n sre-fullstack-lab get deploy,sts,pods,svc,pvc -o wide
    kubectl -n sre-fullstack-lab logs deploy/incidents-api --tail=80
    kubectl -n sre-fullstack-lab logs deploy/incidents-web --tail=60
    kubectl -n sre-fullstack-lab logs statefulset/postgres --tail=80
    kubectl -n sre-fullstack-lab describe pod postgres-0
    kubectl -n sre-fullstack-lab get events --sort-by=.lastTimestamp

Na interface web:
- Testar API + banco: SELECT 1 pelo backend, validando conexão.
- Registrar: POST /api/incidents, cria linha na tabela.
- Atualizar: GET /api/incidents, busca linhas.
- Investigar/Resolver: PATCH /api/incidents/ID, muda status.
- Simular 2 s: atraso artificial via sleep na API, não CPU/I/O/lock real.

Consulta direta ao PostgreSQL (somente leitura):

    kubectl -n sre-fullstack-lab exec postgres-0 -- sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT id, service, severity, status FROM incidents ORDER BY id DESC LIMIT 10;"'

O PVC sobrevive a restart do Pod na mesma sessão, mas **não** ao descarte do KillerCoda. PostgreSQL único não oferece HA. O módulo pede 224 MiB em requests de memória somando PostgreSQL, API e Nginx; Kafka/RabbitMQ também usam recursos e o cluster pode ficar pressionado.

## Trilha de próximos exercícios
1. Validar Pods, PVC, SQL e API.
2. Medir latência do frontend até backend e banco; comparar health com /api/slow.
3. Investigar queries, locks e saturação de recursos num cenário controlado.
4. Medir disponibilidade, latência p95 e métricas, e montar dashboards.
5. Realizar backup e teste de restauração, além de pipeline CI/CD.

Referências:
- https://hub.docker.com/_/postgres
- https://www.psycopg.org/
- https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/

## Aula INC-SRE-003 — Disputa por lock e troubleshooting PostgreSQL

Baseline medido em 12/11/2026: tabela de dois incidentes, Seq Scan, planning 1,025ms e execution 0,082ms; `pg_stat_activity` sem espera naquela consulta. Isso não indica gargalo no banco.

**Exercício novo, publicado e ainda NÃO executado no cluster:**

    cd ~/sre-killercoda-lab
    git pull --rebase origin main
    bash sre-killercoda-lab/labs/fullstack-postgres/test-db-lock.sh

O script segura um bloqueio de linha via `SELECT ... FOR UPDATE` em incidente fictício, inicia uma atualização concorrente de mesmo registro com `lock_timeout` de 3500ms, observa `wait_event_type=Lock`/`pg_blocking_pids` e desfaz ambas as transações com `ROLLBACK`. **Não persistirá atualizações.**

Se o teste confirmar o bloqueio, investigar por que uma transação real ficaria aberta tanto tempo e qual política de timeout/monitoramento convém. Não usar `pg_terminate_backend` em produção sem avaliar o impacto, dono da transação e autorização.
