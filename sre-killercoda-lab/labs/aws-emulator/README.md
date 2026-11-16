# Laboratório AWS Emulator — recuperação em um comando

## Status real em 16/11/2026

- Ubuntu 24.04 (KillerCoda), AWS Emulator 1.0.471 iniciado em HTTPS 127.0.0.1:9297.
- AWS CLI 2.40.4 instalado; assinatura GPG do instalador verificada.
- Identidade do AWS Emulator confirmada: Account 000000000000.
- Aula 01 EXECUTADA COM SUCESSO: bucket curriculos-lab, upload teste.txt, filas curriculos-processar e curriculos-dlq, envio e recebimento SQS.
- Evidências enviadas pelo Luiz no chat. Arquivos de instalação e scripts persistem aqui; estado AWS emulado NÃO persiste.

**Validação do bootstrap em 16/11/2026:** Luiz executou o script de ponta a ponta, com todas as cinco etapas OK, AWS Emulator 1.0.471 e AWS CLI 2.40.4 reconhecidos, S3 e SQS testados e mensagem recebida. **Esse teste foi feito na mesma sessão, com o emulador já ativo e bucket preexistente.** O primeiro boot em uma sessão completamente nova ainda está pendente. A leitura SQS retornou uma mensagem de execução anterior, pois o teste não a exclui da fila.

## Recuperar Aula 01 em qualquer Ubuntu/KillerCoda novo

Abra o terminal de um Ubuntu x86_64 com acesso à Internet e permissão root/sudo. Execute esta linha única:

```bash
if [ -d "$HOME/sre-killercoda-lab/.git" ]; then git -C "$HOME/sre-killercoda-lab" pull --ff-only origin main; else git clone https://github.com/lvbeserra/sre-killercoda-lab.git "$HOME/sre-killercoda-lab"; fi && bash "$HOME/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/bootstrap.sh"
```

O comando busca a versão do GitHub, instala AWS Emulator e AWS CLI v2 se estiverem ausentes, inicia o emulador local, configura credenciais fictícias e recria os recursos S3 e SQS com um teste automático. Se a porta 9297 estiver ocupada por outro serviço, o script aborta sem interrompê-lo.

Se estiver trabalhando em um repositório com modificações próprias, faça commit/stash ou salve suas alterações antes de atualizar. O comando git pull --ff-only não força sobrescrita.

## Usar AWS CLI depois que o bootstrap terminar

```bash
source "$HOME/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/env.sh"
aws sts get-caller-identity
aws s3 ls
aws sqs list-queues
```

## Scripts versionados

- bootstrap.sh — restaura a Aula 01 em um passo.
- install-ubuntu.sh — instalação do pacote AWS Emulator oficial.
- env.sh — configuração local do SDK/CLI; remove possíveis credenciais AWS reais do shell.
- lab01-s3-sqs.sh — criação S3/SQS e teste funcional; aborta sem Account 000000000000.

## Restrições e segurança

- O estado do AWS Emulator é volátil: ao encerrar o processo ou expirar o KillerCoda, buckets/filas são apagados. O script os recria, mas NÃO recupera dados anteriores.
- O GitHub armazena scripts e documentação, não os binários, chaves, certificados nem dados de produção.
- Não inclua em commits credenciais de ~/.aws, PDFs de currículos reais ou dados pessoais.
- AWS Emulator é adequado para desenvolvimento/testes e não substitui AWS para validar segurança/IAM.
- O comando automatiza apenas este laboratório AWS Emulator; não restaura clusters Kubernetes, Control-M ou outros projetos não incluídos no script.

## Próximos laboratórios (AINDA NÃO IMPLEMENTADOS)

1. FastAPI para receber PDFs e publicar no S3/SQS.
2. Dois workers em paralelo, PostgreSQL, idempotência.
3. Retries/DLQ e troubleshooting.
4. Infra como código, GitHub Actions e integração opcional com IA.

Documentação oficial:
- https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-linux.html
- https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html
- https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

## Aula 02 (codigo publicado; teste pendente)

API FastAPI para receber PDF ficticio, armazenar em S3 e publicar evento no SQS.
Manual e comandos: [aula02/README.md](aula02/README.md).
Primeiro execute o bootstrap da Aula 01; depois, em outro terminal:

```bash
bash ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula02/start-api.sh
```

Esta API ainda nao faz processamento do PDF nem grava em PostgreSQL.

## Aula 03 (codigo publicado; teste pendente)

Dois workers SQS concorrentes, extração de texto de PDF e gravacao PostgreSQL idempotente.
Manual: [aula03/README.md](aula03/README.md).

```bash
bash ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula03/install-postgres.sh
bash ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula03/start-workers.sh
```

Importante: configurar 3 tentativas e DLQ e assunto da Aula 04; ainda nao implementado.

## Console web do laboratorio (Aula 03 complementar)

Painel read-only com S3, SQS, PostgreSQL e dois workers, exposto separadamente na porta 8001 do KillerCoda.

```bash
bash ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula02/start-console.sh
```

No KillerCoda abra Traffic / Ports e selecione 8001; acesse /console no link retornado.
Detalhes: [aula02/CONSOLE.md](aula02/CONSOLE.md).
Este painel ainda precisa ser validado no navegador. Nao contem comandos de alteracao ou exclusao de recursos.
