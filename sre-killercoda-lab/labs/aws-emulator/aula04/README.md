# Aula 04 — SQS Retry e Dead Letter Queue (DLQ)

Status: implementada no GitHub; **a execucao no AWS Emulator 1.0.471 ainda precisa de validacao no Killercoda**. O teste detecta se a RedrivePolicy nao for confirmada, sem afirmar sucesso falso.

## Objetivo

Simular consumidor falhando sem ACK/delete_message e demonstrar que a fila SQS de origem envia a mensagem para a DLQ apos exceder 3 recebimentos. Essa semantica depende do suporte real oferecido pela versao local do AWS Emulator.

Filas **isoladas** para nao interferir nos workers da Aula 03:
- `curriculos-aula04` — fila de origem.
- `curriculos-aula04-dlq` — destino dos erros.

## Executar no Ubuntu do Killercoda

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/aula04/run.sh
```

O teste valida endpoint local, CA e conta ficticia 000000000000, cria filas, aplica e rele RedrivePolicy (maxReceiveCount=3), envia uma mensagem de falha ficticia e simula reentregas **sem excluir a mensagem**. Aguarda ate 65 segundos pela movimentacao para DLQ. Nao faz chamadas a conta AWS real.

## Diagnostico

```bash
source ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/env.sh
aws sqs get-queue-url --queue-name curriculos-aula04
aws sqs get-queue-url --queue-name curriculos-aula04-dlq
aws sqs list-queues
```

Abra a console read-only via Traffic / Ports 8001 e adicione `/console`: as novas filas e os contadores devem aparecer ao clicar Atualizar.

Se o teste disser "NAO VALIDADO", nao conclua que houve redrive. O AWS Emulator pode nao implementar por completo esse recurso; registre a evidencia da versao e o erro. A logica de redrive de producao precisa ser testada na AWS real.

O teste pode ser repetido; nao limpa filas antigas nem mensagens e nao executa `purge-queue`.
Documentacao oficial: https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html
