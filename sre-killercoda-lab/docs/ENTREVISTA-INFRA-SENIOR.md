# Entrevista de Infraestrutura Sênior — falar com segurança, sem decorar

Objetivo: transformar competência prática em comunicação técnica clara, sem pressão por perfeição.
Referência: descrição compartilhada da vaga Analista de Infraestrutura Sênior — Hidrovias do Brasil.

## Regras
- Não decorar texto inteiro; usar somente três âncoras: CONTEXTO, AÇÃO, EVIDÊNCIA.
- Começar em 15 segundos, depois aumentar gradualmente para 30 e 60.
- Separar experiência profissional de projetos próprios de laboratório.
- Não inventar atuação com GCP, VMware, SAN, CloudFormation, FinOps nem liderança de migração se não houver um caso real.
- Se der branco: "Vou organizar meu raciocínio em três pontos: contexto, investigação e resultado." É aceitável fazer uma pausa curta.

## Abertura de 30 segundos (modelo)
"Atuo há mais de 18 anos em infraestrutura de TI, com foco em servidores, ambientes Windows e Active Directory, monitoramento e investigação de incidentes. Tenho experiência prática em sustentação e diagnóstico de problemas e venho ampliando minhas habilidades em cloud, automação, Kubernetes e práticas SRE. Costumo começar entendendo o impacto, verificando evidências e validando a solução antes de encerrar um chamado."

A fala é modelo, não compromisso de decorá-la. Ajustar para corresponder ao currículo efetivo.

## Perguntas por tecnologia, com resposta em três linhas

### 1. Como você investiga incidentes complexos?
O que é: análise estruturada por hipótese e evidência.
O que fiz: em cenários de Zabbix, validei serviço, portas de comunicação, configuração de agente e logs para isolar a causa.
Resultado: a análise indica se problema está em rede, agente, configuração ou serviço; nunca afirmar correção sem logs ou teste.

### 2. O que significa infraestrutura híbrida?
O que é: integração de recursos on-premises com nuvem pública.
Onde usar: servidores/AD, conectividade, identidade, backup e aplicações distribuídas.
Como explicar: "Planejo dependências, autenticação, rede, segurança e continuidade dos serviços antes de mover qualquer carga".

### 3. Para que serve IaC?
O que é: infraestrutura declarada e controlada por código.
Diferença: Terraform gerencia recursos por estado/plano; Ansible executa configuração; ARM/CloudFormation são opções nativas.
Limite: ainda será desenvolvido como módulo completo deste repositório; não dizer que foi aplicado em produção por causa do exercício.

### 4. Kafka x RabbitMQ?
Kafka é o registro de eventos; RabbitMQ distribui tarefas e recebe ACK de consumidores.
No laboratório integrei ambos com uma Bridge Python e realizei teste de recuperação do Worker.
Aprendizado: confirmo publicação antes de commitar offset, com possíveis duplicatas mitigadas no consumidor.

### 5. Como você mede disponibilidade?
Medi SLI HTTP sintético e latência P50/P95, gravei histórico SQLite em PVC e simulei falha Apache.
O teste registrou 2 falhas em 13 amostras e retorno de sucesso após restaurar o serviço.
Isso não substitui telemetria real de usuários nem comprova SLO de produção.

### 6. O que é FinOps?
Disciplina de transparência e otimização de custos cloud com responsabilidade de equipes.
Primeiro inventário, tagueamento e medição; depois recomendações como rightsizing, agendamento e retenção.
Requests/limits de Kubernetes não são despesas reais; o módulo inicial é de capacidade, não billing.

### 7. Como trataria uma migração on-premises para cloud?
Inventário e dependências, rede e identidade, RPO/RTO, testes, janela, backup e plano de retorno.
Em seguida validar serviços, latência, segurança, custo e observabilidade pós-migração.
É uma metodologia: não afirmar migração que não foi executada.

## Treino de 3 minutos, sem entrevistador
1. Escolha UM caso real (ex.: agente Zabbix não respondia).
2. Diga uma frase sobre impacto.
3. Diga o primeiro comando ou evidência.
4. Diga a hipótese mais provável.
5. Diga a verificação pós-ação.
6. Pare. Não se critique pela linguagem.

## Exercícios futuros
- Inventário Kubernetes: explicar requests x consumo x custo em 20 segundos.
- Windows: explicar como validar AD, DNS, Netlogon e replicação sem decorar 20 comandos.
- Redes: explicar VPN x VLAN x firewall x Load Balancer com analogias.
- Observabilidade: distinguir log, métrica, trace, alerta, SLI/SLO e objetivo.
- Migração: dizer cinco verificações obrigatórias antes do cutover.
- FinOps: como propor direitosizing sem prometer economia fictícia.

## Perguntas honestas quando ainda não domina uma tecnologia
"Tenho familiaridade conceitual e estou estudando com laboratório, mas não gostaria de apresentar isso como experiência produtiva. Minha abordagem seria validar a documentação, montar uma prova de conceito e aplicar controles de mudança."

Nunca equiparar certificados, prática pessoal e experiência em produção.
