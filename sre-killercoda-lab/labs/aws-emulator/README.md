# Laboratorio AWS Emulator - KillerCoda Ubuntu

Status 16/11/2026: Luiz instalou com sucesso AWS Emulator 1.0.471 e iniciou em HTTPS 127.0.0.1:9297 (logs fornecidos na conversa). Testes S3/SQS pendentes.

## Retomar depois de expirar o KillerCoda

Abra um Ubuntu novo e execute:

    git clone https://github.com/lvbeserra/sre-killercoda-lab.git
    cd sre-killercoda-lab
    bash sre-killercoda-lab/labs/aws-emulator/install-ubuntu.sh

Se o repositorio ja existir, entre nele e use git pull --rebase origin main (somente com alteracoes locais salvas).

Terminal 1: inicie e mantenha aberto:

    aws-emulator --telemetry off

Terminal 2: tenha AWS CLI v2 instalado. Fonte oficial: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

    source sre-killercoda-lab/labs/aws-emulator/env.sh
    aws sts get-caller-identity
    bash sre-killercoda-lab/labs/aws-emulator/lab01-s3-sqs.sh

## Seguranca e persistencia

- O emulador usa a conta ficticia 000000000000; o script aborta se detectar outra.
- NUNCA commitar ~/.aws, certificados, chaves AWS reais, curriculos reais ou dados pessoais.
- O estado dos recursos AWS emulados e em memoria: desaparece quando o emulador para.
- KillerCoda e temporario. O GitHub guarda estes scripts e documentos, NAO o binario instalado nem as filas.
- O emulador e para desenvolvimento/testes, NAO para producao nem auditoria de politicas IAM.

## Proximos labs

1. FastAPI para receber PDF.
2. S3 + SQS com dois workers.
3. PostgreSQL + idempotencia.
4. Retries, redrive para DLQ e troubleshooting.
5. Extracao PDF local gratuita; integracao com IA externa opcional e possivelmente cobrada.

Fontes:
https://docs.aws.amazon.com/emulator/latest/userguide/getting-started-linux.html
https://docs.aws.amazon.com/emulator/latest/userguide/point-sdk-to-emulator.html
https://github.com/aws/aws-emulator
