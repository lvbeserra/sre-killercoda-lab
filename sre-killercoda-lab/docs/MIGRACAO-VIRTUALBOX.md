# Evolução do laboratório SRE: KillerCoda → VirtualBox

**Situação (12/11/2026):** preparação e documentação; ainda não instalamos Kubernetes nem serviços em VirtualBox. O laboratório Kubernetes do KillerCoda já usa `bash iniciar.sh` para restaurar Blue/Green, PostgreSQL + Python + Nginx e middleware, instalando GitHub CLI `gh` se estiver ausente.

## Desenho proposto (primeira etapa)

- **VM1 Ubuntu Server 24.04 LTS:** ponto de partida sugerido 4 vCPU, 8 GiB RAM, 60 GiB disco; validar capacidade do host e ajustar conforme consumo real.
- **Cluster Kubernetes local:** k3s de um único nó em primeiro momento; instalar previamente kubectl, rede/CNI e uma StorageClass persistente. O `iniciar.sh` **não provisiona o cluster**.
- **Serviços reproduzidos do GitHub:** Blue/Green, Graceful Shutdown, Apache/Kafka/RabbitMQ, bridge/worker/observador, PostgreSQL StatefulSet (PVC), API Python e frontend Nginx.
- **VM2 futura opcional (Windows Server):** AD DS, DNS, GPO, observabilidade e cenários híbridos. Não misturar laboratório de domínio Windows com produção nem usar credenciais reais.
- **Redes:** NAT/host-only e segmentação; evitar bridged com portas abertas ao público. UI atual não possui autenticação nem HTTPS.
- **GH CLI:** `setup.sh` verifica `gh` e instala por apt quando disponível; em VM persistente isso acontece somente na primeira instalação, salvo remoção/atualização da VM. Autenticação por navegador quando não houver sessão `gh`.

## Persistência e backup: importante

- O GitHub guarda `schema.sql`, scripts, manifestos, código e progresso; **não contém a base de dados**.
- No KillerCoda, quando o cenário é destruído, PVCs e linhas da tabela também são perdidos. `restore-fullstack.sh` recria a instância e o schema num volume novo, vazio.
- No VirtualBox, um PVC em disco durável deve sobreviver a reinicializações do Pod e da VM, **não** à destruição ou reformatação do disco.
- Antes de considerar o ambiente recuperável: planejar `pg_dump`/backup externo, versão compatível, proteção de senhas e **teste de restauração**. Nunca comitar dump real ou segredos no Git.
- O schema SQL roda automaticamente **apenas no primeiro início** de um PGDATA vazio. Atualizações futuras precisarão de migrações SQL versionadas.

## Inicialização proposta após instalar Kubernetes na VM

```bash
git clone https://github.com/lvbeserra/sre-killercoda-lab.git
cd sre-killercoda-lab
bash iniciar.sh
```

O script instala `gh` quando necessário e valida PostgreSQL/API/Nginx. Se a memória for insuficiente, usar `SRE_ENABLE_MIDDLEWARE=0 bash iniciar.sh` para manter Blue/Green + Full Stack e reduzir a carga.

## Critérios de validação antes de migrar

1. VM com `kubectl get nodes` mostrando nó `Ready` e StorageClass com PVC `Bound`.
2. `bash iniciar.sh` conclui com sucesso e `bash sre-killercoda-lab/labs/fullstack-postgres/validate-fullstack.sh` confirma SQL + API via Nginx.
3. Reiniciar a VM sem apagar o disco; verificar se PostgreSQL conserva incidentes fictícios.
4. Executar `pg_dump` para armazenamento fora da VM e confirmar restauração **numa instância de teste separada**.
5. Adicionar ferramentas de observabilidade, CI/CD, monitoramento de SLO e testes de recuperação sem expor dados nem credenciais.

**Observação:** nenhuma VM foi criada por este documento e a arquitetura proposta é um ponto de partida, não uma homologação de desempenho.
