# Aula SRE Java — WAR Tomcat + JDBC PostgreSQL

**Status em 13/11/2026:** fontes e manifests publicados, **ainda nao testados no KillerCoda**. Laboratorio opcional, somente de leitura.

## Objetivo

Usar um WAR Java real (empacotado com `jar` pelo initContainer), rodar em um Tomcat 10.1 isolado, carregar driver pgJDBC **42.7.14**, conectar via JDBC com usuario/senha vindos do Secret **pg-lab-credentials** e fazer somente `SELECT` na tabela `incidents`.

Arquitetura:

```text
Cliente HTTP -> Service java-jdbc:8080 -> Tomcat 10.1
                                       -> WAR java-jdbc.war (JSP)
                                       -> JDBC pgJDBC 42.7.14
                                       -> Service postgres:5432
                                       -> PostgreSQL 17, tabela incidents
```

- Namespace: **sre-fullstack-lab**, o mesmo do PostgreSQL. Não há cópia de Secrets para outros namespaces.
- Application: novo `Deployment/java-jdbc` e `Service/java-jdbc`; **não substitui** Tomcat, WildFly, Apache nem API Python existentes.
- `JAVA_TOOL_OPTIONS` limita heap a 192Mi; request de memoria 128Mi e limite 384Mi para Tomcat de JDBC, mais initContainer temporario. Observar o nó antes/depois do exercício.
- `readinessProbe` executa JSP/JDBC, sinalizando indisponibilidade do banco, enquanto `livenessProbe` checa a porta TCP sem reiniciar a aplicação por indisponibilidade momentânea do PostgreSQL.
- Driver JDBC 42.7.14 obtido em runtime do **Maven Central por HTTPS**. Precisa de saída para Internet durante instalação. Dependências e imagem devem ser pré-empacotadas, assinadas e fixadas por digest em produção.

## Pré-requisitos

Full Stack validado (`bash sre-killercoda-lab/labs/fullstack-postgres/validate-fullstack.sh`), Secret presente, `postgres-0` saudável, nó de trabalho sem `MemoryPressure`. Na sessão de 13/11, o nó dispunha de ~893MiB após subir WildFly.

## Subir e testar no KillerCoda

```bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/java-jdbc/restore-jdbc.sh
bash sre-killercoda-lab/labs/java-jdbc/validate-jdbc.sh
```

Resultado esperado após sucesso:

```text
SRE Java JDBC Lab
Servidor Java: Apache Tomcat/10.1.x
JDBC: PostgreSQL
Database: srelab
Incidentes: 0
Status: OK
```

`Incidentes: 0` é válido: o banco é novo e vazio nessa sessão. A consulta não grava informações.

## Abrir no navegador (opcional)

No terminal isolado do KillerCoda:

```bash
kubectl -n sre-fullstack-lab port-forward --address 0.0.0.0 svc/java-jdbc 8091:8080
```

Usar KillerCoda Traffic/Ports porta **8091** e caminho **/java-jdbc/index.jsp**. Não compartilhar URL: **sem TLS/autenticacao**. Encerrar port-forward após a aula com Ctrl+C.

## Diagnóstico SRE

```bash
kubectl -n sre-fullstack-lab get pod -l app=java-jdbc -o wide
kubectl -n sre-fullstack-lab describe pod -l app=java-jdbc
kubectl -n sre-fullstack-lab logs deploy/java-jdbc -c package-war --tail=100
kubectl -n sre-fullstack-lab logs deploy/java-jdbc -c tomcat --tail=100
kubectl -n sre-fullstack-lab get events --sort-by=.lastTimestamp | tail -30
```

- **Init:Error / Init:CrashLoopBackOff:** verificar DNS, proxy, certificado TLS e saída HTTPS para Maven Central; não remover dependência JDBC ou desativar TLS para contornar o erro.
- **HTTP 404:** WAR pode não ter sido publicado ou URI estar errada. Checar `/java-jdbc/index.jsp`.
- **HTTP 500 / erro de compilação JSP:** ler logs de Tomcat. Compilação ocorre na primeira requisição.
- **HTTP 503 / SQLSTATE 08001, 08006:** investigar PostgreSQL/DNS/Service, conn timeout, autenticação e readiness; não divulgar senha.
- **SQLSTATE 28P01:** credencial não aceita; verificar referência do Secret e ambiente, sem exibir segredos.
- **Pod OOMKilled:** parar somente a aplicação JDBC, reavaliar memória. Nunca reiniciar PostgreSQL como primeira ação.

## Limpeza do módulo, sem apagar banco

```bash
kubectl -n sre-fullstack-lab delete -f sre-killercoda-lab/labs/java-jdbc/resources.yaml
kubectl -n sre-fullstack-lab delete configmap java-jdbc-source
```

Isso **não** remove PVC ou dados do PostgreSQL. Não apague o namespace `sre-fullstack-lab`.

## Evolução depois do exercício

O JSP abre uma conexão nova por solicitação, propositalmente, para visualizar o fluxo JDBC com pouco código. **Isso não demonstra pool** e não é arquitetura de produção. A próxima aula é configurar `javax.sql.DataSource` e pool via JNDI, comparar throughput e latência, simular timeout de conexão e construir WAR com Maven/GitHub Actions.

Referências:
- https://jdbc.postgresql.org/download/
- https://central.sonatype.com/artifact/org.postgresql/postgresql/versions
- https://tomcat.apache.org/tomcat-10.1-doc/deployer-howto.html
- https://kubernetes.io/docs/concepts/configuration/secret/
