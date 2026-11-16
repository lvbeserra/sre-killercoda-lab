# Aula 02: FastAPI -> AWS Emulator S3 -> AWS Emulator SQS

Status em 16/11/2026: **TESTE DA API APROVADO** pelo Luiz em Ubuntu/KillerCoda: GET /health => status ok; GET /ready => ready (conta emulada 000000000000); PDF ficticio de 607 bytes gerado; POST /resumes => HTTP 202 Accepted, job_id ab4ee810-c9df-4f98-97c7-5da3110fda1e, s3_key uploads/ab4ee810-c9df-4f98-97c7-5da3110fda1e.pdf, sqs_message_id 6c64c84e-2655-4d57-987d-26542b8ac17d. **Conferencia direta por AWS CLI de get-object/recebimento dessa mensagem ainda pendente.** Aula 01 S3/SQS previamente aprovada.

## Arquitetura

Cliente curl -> FastAPI POST /resumes -> bucket S3 curriculos-lab -> SQS curriculos-processar.
Os workers que consomem o SQS e o PostgreSQL serao implementados nas proximas aulas.

## Pre-requisitos

- Ubuntu/KillerCoda x86_64 com AWS Emulator inicializado.
- AWS CLI v2 com credenciais emuladas (000000000000).
- Python3, python3-venv e rede para baixar pacotes Python.
- Os recursos S3/SQS sao criados pela Aula 01, nao por esta API.

## 1. No terminal Linux atual

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/bootstrap.sh
```

## 2. Abrir outro terminal (o 1o pode ser reutilizado se bootstrap finalizou)

Se o Ubuntu ainda nao tiver python3-venv (a instalacao e local ao laboratorio):

```bash
apt-get update
apt-get install -y python3-venv
```

Rodar API em primeiro plano:

```bash
cd ~/sre-killercoda-lab
bash sre-killercoda-lab/labs/aws-emulator/aula02/start-api.sh
```

Espere: API iniciando em http://127.0.0.1:8000

## 3. Em outro terminal, testar

```bash
curl -fsS http://127.0.0.1:8000/health
curl -fsS http://127.0.0.1:8000/ready
python3 ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/aula02/gerar-pdf-teste.py /tmp/curriculo-ficticio.pdf
curl -i -F 'file=@/tmp/curriculo-ficticio.pdf;type=application/pdf' http://127.0.0.1:8000/resumes
```

Esperado: HTTP 202 com job_id, s3_key e sqs_message_id.

Para comprovar os recursos criados, execute no mesmo terminal de testes:

```bash
source ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/env.sh
aws s3 ls s3://curriculos-lab/uploads/
QUEUE_URL=$(aws sqs get-queue-url --queue-name curriculos-processar --query QueueUrl --output text)
aws sqs receive-message --queue-url "$QUEUE_URL" --max-number-of-messages 10
```

Nota: a fila ja contem mensagens da Aula 01. Examine o job_id/s3_key no corpo para localizar a mensagem nova. A operacao receive-message nao exclui a mensagem; sem worker, ela pode voltar a ser entregue apos o prazo de invisibilidade.

## Falhas esperadas

- 415: arquivo nao tem extensao .pdf ou nao comeca com %PDF-.
- 413: arquivo maior que 5 MiB.
- 503: emulador parou, bucket/fila ausente ou falha de integracao.
- Porta 8000 ocupada: pare o processo responsavel somente se ele for do seu laboratorio.
- Se S3 gravar mas SQS falhar, pode ficar um objeto sem mensagem: ainda nao ha mecanismo de conciliacao; sera tratado nos labs posteriores.

## Seguranca

- API vinculada a 127.0.0.1:8000, somente acesso local.
- Nao use curriculos reais ou dados pessoais no laboratorio.
- O codigo verifica endpoint fixo 127.0.0.1:9297 e identidade ficticia 000000000000.
- Nao use o codigo como API publica de producao; faltam autenticacao, quotas, antivirus, observabilidade e persistencia.

Documentacao:
https://fastapi.tiangolo.com/tutorial/request-files/
https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html
