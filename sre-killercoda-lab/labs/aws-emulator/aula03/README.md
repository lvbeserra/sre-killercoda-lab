# Aula 03: 2 workers concorrentes + PostgreSQL + idempotencia

STATUS: codigo publicado em 16/11/2026, AINDA NAO TESTADO PELO USUARIO.

## Objetivo

Consumir mensagens da fila SQS curriculos-processar, buscar PDFs no S3, extrair texto local com pypdf e gravar o resultado em PostgreSQL.
Cada job_id sera registrado apenas uma vez. O worker faz lock transacional do job_id antes de processar, confirma o COMMIT no PostgreSQL e so depois executa delete_message no SQS.
Em caso de falha, a mensagem nao e deletada e pode ser entregue novamente apos visibility timeout. Isto nao e garantia de entrega exatamente uma vez; e processamento idempotente sobre SQS at-least-once.

## Etapa 1 - Atualizar repositório e conferir Aula 01

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/bootstrap.sh
```

Se a API da Aula 02 nao estiver rodando e precisar gerar novo PDF, execute-a em outro terminal:

```bash
bash ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula02/start-api.sh
```

## Etapa 2 - Instalar PostgreSQL e esquema

Somente Ubuntu/KillerCoda proprio de laboratorio, como root:

```bash
bash sre-killercoda-lab/labs/aws-emulator/aula03/install-postgres.sh
```

Cria banco local sre_curriculos, role root sem superusuario e tabela processed_jobs. Usa autenticação peer do PostgreSQL no socket local, sem senha em Git.

## Etapa 3 - Iniciar dois workers

```bash
bash sre-killercoda-lab/labs/aws-emulator/aula03/start-workers.sh
```

Logs:

```bash
tail -n 30 /tmp/aws-emulator-worker-1.log
tail -n 30 /tmp/aws-emulator-worker-2.log
```

Mensagens da Aula 01 sem job_id nao serao excluidas: os workers registram aviso e as deixam para analise. Nao use purge-queue neste laboratorio sem decidir quais mensagens podem ser perdidas.

## Etapa 4 - Enviar novo PDF

```bash
python3 ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula02/gerar-pdf-teste.py
curl -i -F 'file=@/tmp/curriculo-ficticio.pdf;type=application/pdf' http://127.0.0.1:8000/resumes
```

Esperado: API HTTP 202 e um job_id. Os workers consumirao e excluirao a mensagem apos COMMIT.

## Etapa 5 - Conferir PostgreSQL

```bash
psql -d sre_curriculos -c "SELECT job_id, worker_id, left(extracted_text, 70) AS texto, processed_at FROM processed_jobs ORDER BY processed_at DESC LIMIT 10;"
```

Para ver dois workers ativos:

```bash
pgrep -af 'worker.py'
```

## Etapa 6 - Testar duplicidade (opcional)

Com a API ja funcionando e um job_id processado, envie novamente ao SQS a mesma mensagem com mesmo job_id, bucket e key.
Veja que os logs mostram DUPLICADO e que o SELECT acima continua com uma so linha para esse job_id.

## O que ainda falta

- Nao ha pipeline de IA real: pypdf extrai somente texto existente no PDF, nao faz OCR em imagens.
- Nao ha 3 tentativas/Redrive Policy/DLQ configurada; isso sera Aula 04.
- O bootstrap.sh atual restaura a Aula 01; PostgreSQL/workers sao provisionados por comandos desta aula. Serao incluidos no bootstrap unico apos teste real.
- Nao usar dados pessoais ou PDFs de curriculos verdadeiros.
- Ambiente temporario: ao expirar KillerCoda, perde-se o estado emulado e banco local; GitHub guarda scripts e esquema.

Fontes oficiais:
https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html
https://www.postgresql.org/docs/current/explicit-locking.html
https://www.psycopg.org/psycopg3/docs/basic/transactions.html
https://pypdf.readthedocs.io/en/latest/user/extract-text.html
