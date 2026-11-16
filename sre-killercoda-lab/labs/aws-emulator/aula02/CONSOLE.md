# Console web do AWS Emulator - SRE Lab

STATUS: codigo publicado em 16/11/2026; acesso ao navegador ainda precisa ser testado pelo Luiz no Killercoda.

## O que mostra

- Buckets S3 e ate 25 objetos por bucket (somente nomes e tamanhos).
- Filas SQS e contadores aproximados de mensagens, sem realizar receive-message.
- Ultimos 20 jobs da tabela PostgreSQL processed_jobs.
- Estado e oito ultimas linhas dos logs dos workers 1 e 2.
- Indicacao visivel de ambiente emulado, nao AWS Management Console.

## Iniciar no Ubuntu do Killercoda

Depois de AWS Emulator, API da Aula 02 e PostgreSQL/workers da Aula 03 estarem funcionando:

```bash
cd ~/sre-killercoda-lab
git pull --ff-only origin main
bash sre-killercoda-lab/labs/aws-emulator/aula02/start-console.sh
```

A API e a porta 8000 continuam vinculadas ao endereco local. O console roda em um processo SEPARADO, na porta 8001, oferecendo apenas GET /console, GET /console/state e GET /health.

Teste do terminal:

```bash
curl http://127.0.0.1:8001/health
curl http://127.0.0.1:8001/console/state
```

## Abrir pelo navegador no Killercoda

1. Na area superior direita do terminal, clique em Traffic / Ports.
2. Selecione o host Ubuntu e a porta 8001.
3. Abra o link HTTP gerado e acrescente /console ao final, caso nao apareca automaticamente.

Opcional: o proprio Killercoda disponibiliza um arquivo para construir o link da porta:

```bash
sed 's/PORT/8001/g' /etc/killercoda/host
```

O usuario devera usar o link retornado pelo seu proprio Killercoda; nao existe uma URL fixa para compartilhar.

## Seguranca e limites

- A porta 8001 fica acessivel pela funcionalidade Traffic / Ports. NAO envie dados pessoais, credenciais ou curriculos reais nesse laboratorio.
- O painel e somente leitura: nao cria, recebe ou deleta objetos/mensagens pela interface.
- O codigo nao avalia politicas IAM e o AWS Emulator nao simula a console oficial.
- Se qualquer secao nao conseguir consultar seu servico, o painel mostra aviso sem interromper as outras secoes.
- O estado desaparece ao expirar o Killercoda. GitHub armazena os arquivos, nao os dados.

Referencia Killercoda: https://killercoda.com/creators
Referencia AWS: https://docs.aws.amazon.com/emulator/latest/userguide/what-is-service.html
