# Aula 06 — DynamoDB no AWS Emulator

**Validado manualmente pelo Luiz em 17/11/2026, AWS Emulator 1.0.489**:
- create-table para `sre-lab-jobs`, HASH `job_id` (S), PAY_PER_REQUEST;
- describe-table retornou ACTIVE, ItemCount=0;
- put-item gravou o registro ficticio JOB-001;
- get-item recuperou todos os campos;
- scan retornou Count=1, ScannedCount=1.

## Rodar novamente (script versionado)

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/aula06/run.sh
```

O script evita sobrescrever o registro JOB-001 quando ja existir; outros dados na tabela sao preservados. Valida sempre endpoint local e conta ficticia antes de criar algo. **A execução automatizada ainda precisa ser validada pelo Luiz; os comandos manuais acima ja foram comprovados.**

Para consultar todos os itens:

```bash
source ~/sre-killercoda-lab/sre-killercoda-lab/labs/aws-emulator/env.sh
aws dynamodb scan --table-name sre-lab-jobs
```

## Limites

- DynamoDB do AWS Emulator e simulado; nao gera cobranca da AWS real.
- Nao testa latencia, throughput, disponibilidade ou politicas IAM reais.
- Tabela e itens emulados desaparecem com o termino da sessao.
- Integracao automatica FastAPI/worker -> DynamoDB **ainda nao implementada**.
