# Middleware Java SRE: Apache HTTP Server, Tomcat e WildFly

Criado em 13/11/2026 para o SRE KillerCoda. Arquivos publicados, mas **implantacao ainda nao executada pelo usuario**. Nao usar fora de laboratorio isolado.

## Quando escolher

| Tecnologia | Papel | Exemplo |
|---|---|---|
| Apache HTTP Server (httpd) | Proxy reverso, site estatico e entrada HTTP | Encaminha URL /tomcat/ e /wildfly/ para Services do Kubernetes |
| Apache Tomcat | Container Servlet/JSP | Aplicacoes Web e APIs Java que nao precisam de servidor Jakarta EE completo |
| WildFly (projeto comunitario) | Servidor Jakarta EE com recursos corporativos | JPA, JTA, CDI, EJB, JMS conforme aplicacao |
| JBoss EAP (Red Hat) | Produto empresarial relacionado a WildFly | Operacao com suporte, compatibilidade e ciclo de vida Red Hat; NAO instalado aqui |

Importante: Apache HTTP Server e Apache Tomcat sao produtos diferentes e podem trabalhar juntos. Tomcat 9 usa APIs Java EE/Javax; Tomcat 10.1 usa Jakarta EE/Jakarta e a migracao pode exigir adaptacao. WildFly e JBoss EAP nao sao identicos.

## Arquitetura

~~~text
Navegador -> Apache httpd :80 -> /tomcat/  -> Service tomcat-app :8080 -> JSP
                              -> /wildfly/ -> Service wildfly-app :8080 -> JSP (opcional)
~~~

Namespace: sre-java-lab. So usamos Services ClusterIP, sem NodePort/LoadBalancer e sem autenticacao. A pagina JSP exibe o servidor Java e uma data UTC. Nao acessa o PostgreSQL existente.

## Sessao nova KillerCoda

~~~bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
# Sobe o lab principal, Full Stack e gh CLI. Evita Kafka/RabbitMQ nesta aula para poupar RAM:
SRE_ENABLE_MIDDLEWARE=0 bash iniciar.sh
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh
~~~

## Sessao ja iniciada

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh
~~~

O modulo Java e OPT-IN: nao e iniciado pelo iniciar.sh. O KillerCoda pode ter pouca memoria; verifique capacidade. Se middleware antigo ja esta rodando, SRE_ENABLE_MIDDLEWARE=0 apenas pula sua reinstalacao, NAO o desliga.

## Validar

~~~bash
kubectl -n sre-java-lab get pods,svc,deploy -o wide
bash sre-killercoda-lab/labs/java-middleware/validate-java.sh
~~~

Saida esperada inclui: SRE Java Middleware Lab, Servidor: Apache Tomcat/10.1.x, Status: OK.

Para visualizar via KillerCoda Traffic / Ports -> Host 1, porta 8090:

~~~bash
kubectl -n sre-java-lab port-forward svc/apache-gateway 8090:80
~~~

Abra a rota /tomcat/index.jsp. Se o preview exigir ouvir em todas interfaces, encerre o comando acima com Ctrl+C e, SOMENTE neste laboratorio isolado, execute:

~~~bash
kubectl -n sre-java-lab port-forward --address 0.0.0.0 svc/apache-gateway 8090:80
~~~

Nao compartilhar a URL nem usar dados reais, pois nao ha autenticacao/TLS.

## WildFly, opcional e mais pesado

Executar somente com RAM livre e depois do Tomcat validado:

~~~bash
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly
bash sre-killercoda-lab/labs/java-middleware/validate-java.sh
~~~

Teste /wildfly/index.jsp. Imagem comunitaria quay.io/wildfly/wildfly-ee-10:latest-jdk17 (Jakarta EE 10). O deployment scanner usa WAR explodido e marcador .dodeploy. Os tags nao estao fixados por digest; nao usar diretamente em producao.

Para remover so WildFly (nao mexer no PostgreSQL):

~~~bash
kubectl -n sre-java-lab delete -f sre-killercoda-lab/labs/java-middleware/wildfly.yaml
~~~

## Troubleshooting SRE

~~~bash
kubectl -n sre-java-lab get pods -o wide
kubectl -n sre-java-lab logs deploy/tomcat-app --tail=80
kubectl -n sre-java-lab logs deploy/apache-gateway --tail=80
kubectl -n sre-java-lab describe deploy tomcat-app
kubectl -n sre-java-lab get events --sort-by=.lastTimestamp
kubectl -n sre-java-lab exec deploy/apache-gateway -- sh -c 'wget -qO - http://127.0.0.1/tomcat/index.jsp'
~~~

Se WildFly estiver instalado, investigue tambem logs deploy/wildfly-app e descreva o Pod. Perguntas: 503 vem do proxy ou da aplicacao? Readiness ou startup falhou? WAR/JSP publicado? OOMKilled? JVM e GC? Rede entre Services?

## Proximas aulas

- Criar um WAR versionado com /health, /ready, /version e metricas para implantar em Tomcat e WildFly.
- Integrar JDBC, datasource, pool e PostgreSQL; provocar falhas e investigar locks.
- JVM: heap, GC, thread dumps, conexoes e latencia p95 com amostragem adequada.
- Apache reverse proxy: timeout, 503, upstream, log, balanceamento e rollback.
- Comparar WildFly comunitario e JBoss EAP empresarial em termos de suporte e administracao, sem confundir os produtos.

Fontes oficiais:
- https://httpd.apache.org/docs/2.4/howto/reverse_proxy.html
- https://tomcat.apache.org/whichversion.html
- https://hub.docker.com/_/tomcat
- https://docs.wildfly.org/wildfly-container/
- https://www.wildfly.org/guides/wildfly-ee-10-feature-pack/


## Verificacao de capacidade antes de ativar WildFly — 13/11/2026

Nos dois nodes, o usuario observou requests de memoria de **210Mi (9%) e 570Mi (31%)**; limites de memoria de **1364Mi (63%) e 2848Mi (157%)**. Os limites acima de 100% representam overcommit, **nao** uso real de RAM. Os nomes dos nodes nao apareceram no recorte do comando anterior.

A imagem WildFly foi atualizada para `quay.io/wildfly/wildfly-ee-10:latest-jdk21` (EE10/JDK21), e o initContainer passa a dar posse do diretorio do WAR ao UID/GID 1000 usado pela imagem. Essa nova configuracao foi publicada, mas **ainda nao foi testada no KillerCoda**.

Antes da instalacao, avaliar:

~~~bash
kubectl top nodes
kubectl top pods -A --sort-by=memory
kubectl get nodes -o custom-columns='NODE:.metadata.name,MEMORY_ALLOCATABLE:.status.allocatable.memory,CPU_ALLOCATABLE:.status.allocatable.cpu'
kubectl describe nodes | grep -A 8 'Allocated resources:'
~~~

Se o Metrics Server nao estiver disponivel, `kubectl top` nao fornece o consumo real; nao deduzir consumo pelos requests/limits. Se houver `MemoryPressure` ou carga excessiva, nao ativar WildFly ainda. O perfil do laboratorio usa request 512Mi e limite 1200Mi para WildFly.

Depois que os dados forem avaliados, executar manualmente:

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly
bash sre-killercoda-lab/labs/java-middleware/validate-java.sh
~~~

A imagem usa tag movel; para ambientes permanentes fixar imagem/digest aprovado apos teste, evitar atualizar sem controle. Nao confundir WildFly comunitario com JBoss EAP comercial.

## Perfil de memória reduzido para o WildFly (13/11/2026)

Kubelet Summary API: `controlplane` com working set **1454 MiB** e available **792 MiB**; `node01` com working set **1096 MiB** e available **808 MiB**. Maiores consumidores no node01: Cilium 345 MiB, Tomcat 120 MiB, Cilium Envoy 58 MiB, API 40 MiB, PostgreSQL 28 MiB e Apache 6 MiB.

**Perfil WildFly ajustado (substitui a configuração antiga de 512Mi/1200Mi):**
- request de memória: **256Mi**; limite **640Mi**.
- JVM via `JAVA_OPTS`: `-Xms128m -Xmx256m -XX:MaxMetaspaceSize=192m`.
- Imagem: `quay.io/wildfly/wildfly-ee-10:latest-jdk21`, servlet JSP simples e volume de deploy `emptyDir`.

O perfil é uma hipótese de dimensionamento para aula simples, **não uma garantia de funcionamento**. Mesmo com o limite de 640Mi, o node01 teria pouca folga se o WildFly consumisse o máximo. Observar o nó e o Pod; em caso de OOMKilled, falhas de readiness ou MemoryPressure, interromper apenas o WildFly e reavaliar o consumo.

Depois de `git pull --rebase origin main`:

~~~bash
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly
bash sre-killercoda-lab/labs/java-middleware/validate-java.sh
kubectl -n sre-java-lab get pods -o wide
kubectl -n sre-java-lab get events --sort-by=.lastTimestamp
kubectl -n sre-java-lab logs deploy/wildfly-app --tail=80
~~~

Para reverter a implantação do WildFly sem mexer no Tomcat, Apache ou PostgreSQL:

~~~bash
kubectl -n sre-java-lab delete -f sre-killercoda-lab/labs/java-middleware/wildfly.yaml
~~~

**Estado:** perfil publicado no GitHub e ainda NÃO validado pelo estudante no KillerCoda.


## INC-SRE-004 — CrashLoopBackOff por requisito de CPU x86-64-v3 (13/11/2026)

**Incidente executado e diagnosticado no KillerCoda:**
- WildFly `quay.io/wildfly/wildfly-ee-10:latest-jdk21` iniciava em `node01` e falhava instantaneamente com `CrashLoopBackOff`, `ExitCode 127` e log **`Fatal glibc error: CPU does not support x86-64-v3`**.
- InitContainer `prepare-exploded-war` terminou `Completed / exit 0`. O Tomcat e Apache continuaram saudáveis. Não há evidência de OOM: falha é incompatibilidade de CPU da imagem.
- Causa: desde WildFly 41 as imagens passaram de `ubi9-minimal` para `ubi10-minimal`; o RHEL 10 requer x86-64-v3. O processador visível ao cluster não atende. **Não tentar consertar com memória ou probes.**
- **Correção em avaliação (ainda não implantada pelo usuário):** imagem EE10 **`quay.io/wildfly/wildfly-ee-10:40.0.1.Final-jdk21`**, lançada para UBI9, JDK21. É tag fixa antiga, escolhida apenas para compatibilidade em laboratório efêmero; avaliar patches/CVEs para outros usos.
- O `restore-java.sh --with-wildfly` agora restaura `replicas=1` inclusive se o Deployment foi escalado para zero para contenção.

### Recuperar com segurança (somente no lab)

~~~bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
# O restore aplica imagem corrigida sem mexer no PostgreSQL nem nos outros namespaces.
bash sre-killercoda-lab/labs/java-middleware/restore-java.sh --with-wildfly
bash sre-killercoda-lab/labs/java-middleware/validate-java.sh
kubectl -n sre-java-lab get pods -o wide
~~~

Se houver nova falha:

~~~bash
kubectl -n sre-java-lab get pods -l app=wildfly-app -o wide
kubectl -n sre-java-lab logs deploy/wildfly-app -c wildfly --previous --tail=80
kubectl -n sre-java-lab describe pod -l app=wildfly-app
~~~

**Interromper tentativas sem excluir configurações:** `kubectl -n sre-java-lab scale deployment/wildfly-app --replicas=0`.

### Referências oficiais
- https://www.wildfly.org/news/2026/07/16/WildFly-41-is-released/ — adoção do UBI 10
- https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/considerations_in_adopting_rhel_10/architectures — requisitos de CPU x86-64-v3
- https://github.com/wildfly/wildfly/releases/tag/40.0.1.Final — JDK 21/UBI 9
- https://www.wildfly.org/guides/wildfly-ee-10-feature-pack/ — tags de imagens EE10
