# Trilha SRE — Control-M do zero

**Status em 13/11/2026:** materiais publicados no GitHub; **aula ainda não executada pelo usuário**. O script da aula 01 é uma **simulação educativa com Shell, NÃO é Control-M**. Os JSONs são definições Control-M Automation API para testar posteriormente no Workbench BMC real; o build/deploy deles ainda não foi validado na instalação BMC.

## Por que estudar

Perfil-alvo da vaga: Control-M/EM (Enterprise Manager), Control-M/Server e Control-M/Agent; instalar/configurar, migrar e atualizar; jobs/calendários/permissões, Shell/Batch/SQL, análise de logs, incidentes críticos, contingência e retorno. O objetivo é executar diagnósticos e mudanças **em ambientes de laboratório**, com controles de autorização aplicáveis a produção.

## Arquitetura

```text
        Control-M/EM
    console, perfis e monitoração
               |
        Control-M/Server
   regras, calendário, dependências
               |
       Control-M/Agent
      execução de Shell/SQL
               |
        Sistemas de destino
      Linux, Windows, banco, cloud
```

O **Workbench real** é uma solução de desenvolvimento autocontida, e não substitui uma implantação empresarial completa de Control-M/EM + Server + Agents em ambientes de produção. A BMC exige acesso ao EPD com permissão de download para obter sua imagem.

## Aula 01A — Sem licença, começar AGORA no KillerCoda (conceitos, não Control-M)

O laboratório atual já usa quase toda a memória de um nó para Kubernetes, Tomcat, WildFly e PostgreSQL. **Não tentar instalar Workbench nele.** Exercício Shell apenas cria arquivos fictícios em `/tmp`, não toca no Kubernetes.

```bash
cd ~/sre-killercoda-lab
git pull --rebase origin main
bash sre-killercoda-lab/labs/controlm/aula01-local.sh
```

Saída esperada:
- `JOB_01_PRECHECK` => `END OK`
- `JOB_02_PROCESSAMENTO` => `END OK`
- `JOB_03_VALIDACAO` => `END OK`

Provoque a falha **intencional**:
```bash
bash sre-killercoda-lab/labs/controlm/aula01-local.sh --falhar
```

Resultado esperado: `JOB_02_PROCESSAMENTO END NOTOK / ExitCode=42` e `JOB_03_VALIDACAO WAIT/BLOQUEADO`. O comando termina com exit 42 propositalmente. **Não é falha do cluster**. Leia o caminho de evidências `/tmp/controlm-lab-...` exibido no terminal, com `cat /tmp/controlm-lab-.../JOB_02_PROCESSAMENTO.log` usando o caminho real da saída. Execute novamente sem `--falhar` para simular recuperação e validar a cadeia.

Valide a sintaxe dos jobs-as-code (aqui somente JSON, **sem** validação Control-M):
```bash
python3 -m json.tool sre-killercoda-lab/labs/controlm/jobs-sucesso.json >/dev/null && echo "JSON sucesso: sintaxe OK"
python3 -m json.tool sre-killercoda-lab/labs/controlm/jobs-falha.json >/dev/null && echo "JSON falha: sintaxe OK"
```

## Aula 01B — Control-M Workbench REAL, em computador dedicado

### Requisitos oficiais BMC (confirmados em novembro de 2026)

- Docker Desktop (Windows com backend WSL 2) ou Docker Engine em Linux.
- Reservar **no mínimo 8 GiB** de memória **para o container Workbench**, mais memória para o SO. Quatro CPUs no exemplo oficial.
- Porta 8443 livre; porta 7005 adicional se usar Provision/external agents.
- Conta BMC com permissão para baixar **Control-M/Enterprise Manager** no **EPD — Electronic Product Distribution** e acesso ao registry `distribution.bmc.com`.
- A documentação BMC atual consultada mostra a imagem `distribution.bmc.com/ctmem/workbench:9.27.5-GA`; confirme a tag mais recente no portal antes do pull, porque versões mensais mudam.

No notebook Windows de 16 GiB do usuário, uma VM VirtualBox adicional de 8 GiB e os serviços Windows podem deixar recursos insuficientes. **Preferir Docker Desktop+WSL2**, reduzir outros serviços, verificar se o motor Docker tem 8 GiB disponíveis e se há memória residual confortável. Não executar simultaneamente Workbench e VMs pesadas sem monitorar.

### Pré-check PowerShell (Windows)

```powershell
wsl --status
docker version
docker info --format '{{.MemTotal}}'
Get-NetTCPConnection -LocalPort 8443 -State Listen -ErrorAction SilentlyContinue
```

Se `docker` não for reconhecido, instalar e iniciar Docker Desktop por procedimento oficial. Se `wsl` estiver ausente/desativado, configurar WSL2 conforme documentação Microsoft/Docker antes de instalar imagem.

### Obter autorização e imagem

Acesse: https://www.bmc.com/support/resources/product-downloads.html

Na área EPD: **Product Download Tool → Container Products → Control-M/Enterprise Manager → Container Access Product**, seguindo as instruções para gerar um **Identity Token**. O BMC Workbench é descrito como *no-cost*, mas não significa download anônimo: requer permissões de EPD. Não compartilhar token, username ou screenshot de credenciais.

No terminal PowerShell, autentique-se **interativamente** — NÃO passar token por linha de comando (`-p` fica no histórico):

```powershell
docker login distribution.bmc.com -u SEU_USUARIO_BMC
```

Quando solicitar `Password`, colar token **somente no terminal local**, nunca nesta conversa. Em seguida:

```powershell
docker pull distribution.bmc.com/ctmem/workbench:9.27.5-GA
docker run -dt --name controlm-workbench --hostname workbench --cpus=4 -m 8g -p 8443:8443 distribution.bmc.com/ctmem/workbench:9.27.5-GA
docker ps --filter name=controlm-workbench
```

O download e o container **não foram executados por ChatGPT**: esses comandos devem ser rodados pelo usuário após obter direito de acesso. Caso o BMC EPD negue acesso, **não** usar imagens não oficiais, cracks, senhas publicadas ou truques para burlar autenticação. Continuar com Shell/JSON e solicitar acesso oficial.

Quando o container estiver saudável, abrir localmente: `https://localhost:8443/automation-api/startHere.html`. A página usa HTTPS; seguir o guia BMC para certificados de desenvolvimento e credenciais iniciais. Não publicar a porta 8443 na internet, nem reutilizar senhas reais em laboratório.

### Aula 01C — Jobs reais (dependente de Workbench + Control-M Automation CLI)

Instale o CLI oficial conforme instruções do Workbench. Depois configure o environment segundo a BMC:

```bash
ctm environment workbench::add
ctm environment set workbench
ctm config servers::get
```

No computador que tenha as definições clonadas e acesso ao Workbench:

```bash
ctm build sre-killercoda-lab/labs/controlm/jobs-sucesso.json
ctm run sre-killercoda-lab/labs/controlm/jobs-sucesso.json
# Copie o runId informado pela execução, depois:
ctm run status SEU_RUN_ID
```

No segundo fluxo (falha intencional):
```bash
ctm build sre-killercoda-lab/labs/controlm/jobs-falha.json
ctm run sre-killercoda-lab/labs/controlm/jobs-falha.json
ctm run status SEU_RUN_ID_DA_FALHA
```

Os JSONs seguem a sintaxe oficial **`Folder`**, **`Job:Command`** e **`Flow.Sequence`**, com `RunAs: workbench`, que pode variar conforme versão/ambiente. **Ainda não houve `ctm build` ou `ctm run` em Workbench real neste curso.** Se o build retornar erro, registrar a mensagem e corrigir contra o schema do servidor, sem editar produção.

## Resultados e incidentes a estudar

| Incidente | Evidência | Ação segura de laboratório |
|---|---|---|
| Job retorna exit 42 | Output e log; status NOTOK | Identificar causa e rerun controlado |
| Job seguinte não executa | Dependência `Flow` | Não forçar sem avaliar pré-requisito |
| Agent não comunica | Agentes/ports/logs | Testar DNS, firewall, certificados e status |
| Job SQL falha | SQLSTATE, timestamp e log | Verificar credencial/conectividade, evitar gravar segredos |
| Upgrade não inicia | Backups e versão | Rollback conforme procedimento BMC homologado |

## Referências oficiais BMC

- https://github.com/controlm/workbench (BMC, requisitos, autenticação e exemplo)
- https://documents.bmc.com/supportu/API/Monthly/en-US/Documentation/API_Installation.htm (instalação BMC)
- https://github.com/controlm/automation-api-quickstart/blob/master/control-m/101-create-first-job-flow/AutomationAPISampleFlow.json (JSON de fluxo)
- https://docs.bmc.com/xwiki/bin/view/Control-M-Orchestration/Control-M/workloadautomation/Control-M-Automation-API/ctmapi921/Tutorials/Tutorial-Creating-your-first-job-flow/


## Manual detalhado Control-M/Server 9.0.27

Novo manual de instalação e administração real da edição BMC Control-M/Server 9.0.27 no Linux, com arquitetura, dimensionamento, RHEL 9, requisitos, conta dedicada, Java externo, CheckReq, setup.sh, instalação silenciosa por XML gerado, PostgreSQL BMC, EM/Agent, portas/TLS, systemd, troubleshooting, backup, upgrade e rollback.

- [Manual completo em Markdown](MANUAL-INSTALACAO-CONTROL-M-SERVER-LINUX.md)
- [Script read-only de pré-check da VM Linux](precheck-server-linux.sh)

No **servidor Linux dedicado** autorizado (NÃO no Kubernetes/KillerCoda atual), depois de baixar este repositório:

    bash sre-killercoda-lab/labs/controlm/precheck-server-linux.sh

**Cuidado:** a plataforma completa BMC não é gratuita nem pública; requer licença/evaluation e mídia oficial via EPD, com requisitos mínimos do Control-M 9.0.27: Server 4 vCPU, RAM 8 GiB (+4 GiB para PostgreSQL local), 40 GiB disco; Full EM+Server 20 GiB RAM (+4 GiB para DB local), 100 GiB disco. A máquina pessoal Windows com 16 GiB não possui folga recomendada para o Full.

O manual foi criado e revisado contra fontes oficiais, porém **a instalação não foi executada** no ambiente do usuário: falta mídia/contrato autorizado e VM dedicada.


## Instalação tradicional COMPLETA (EM + Server + Agent + PostgreSQL)

**Novo roteiro prático passo a passo (14/11/2026):**

- [GUIA-FULL-INSTALLATION-PASSO-A-PASSO.md](GUIA-FULL-INSTALLATION-PASSO-A-PASSO.md) — VM Full Linux 9.0.27, 24 GiB RAM + 4vCPU + 100 GB disco, pré-requisitos RHEL, conta tcsh, Java externo, EPD, CheckReq \`ONE\`, instalador oficial \`setup.sh\`, configuração EM/Server/Agent/PostgreSQL, Web HTTPS, primeiro job e validação/recuperação, mais variante distribuída para produção.
- [precheck-full-linux.sh](precheck-full-linux.sh) — inventário read-only próprio do curso, **não** é o CheckReq oficial BMC.

No Linux **do servidor dedicado** (não no KillerCoda do usuário), depois de clonar o repositório:
\`\`\`bash
bash sre-killercoda-lab/labs/controlm/precheck-full-linux.sh
\`\`\`

A BMC requer licenciamento/trial e mídia oficial EPD; o programa proprietário **ainda não foi instalado pelo usuário**. Full Installation é recomendada pela BMC para teste, arquitetura distribuída para produção. O manual anterior \`MANUAL-INSTALACAO-CONTROL-M-SERVER-LINUX.md\` permanece para **Server-only**, não confundir.
