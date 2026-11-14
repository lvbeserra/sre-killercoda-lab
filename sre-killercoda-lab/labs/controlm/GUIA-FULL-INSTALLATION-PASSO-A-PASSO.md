# Instalação tradicional COMPLETA do Control-M 9.0.27 — roteiro executável em Linux

**14/11/2026 • Referência: documentos oficiais BMC 9.0.27 • Somente ambiente LAB autorizado**  
**Status:** roteiro escrito e conferido com a documentação BMC; **NÃO executado no servidor do usuário**. A mídia proprietária e a licença/trial precisam ser obtidas pela BMC. **NÃO tentar instalar no KillerCoda, que tem ~2 GiB de RAM.**

> **Diferencie os dois produtos a instalar:**  
> (1) **FULL INSTALLATION** instala Control-M/Enterprise Manager, Control-M/Server, Agent, Automation API e banco associado **na mesma VM**; serve para **laboratório**, não é a arquitetura recomendada para produção.  
> (2) **DISTRIBUTED INSTALLATION** instala EM e Server em VMs/contas separadas e Agents nos destinos; a BMC **recomenda essa topologia para produção**. O Server-only já instala Agent local obrigatório.  
> Fonte: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Introduction_to_Control-M_Installation.htm

## Fase 0 — VM, download e pré-requisitos oficiais

Para **Full Installation Small em Linux x86_64**:
- 4 vCPU (mínimo de referência);
- 20 GB de memória + **4 GB se o PostgreSQL estiver na mesma VM** = **24 GB de RAM**;
- **100 GB de disco** para instalação, mais folga para logs e backups; swap recomendado pela BMC ~1,5 × RAM;
- SO Linux homologado, exemplo de projeto: **RHEL 9 x86_64**, após conferir a matriz de Release Notes da versão/patch;
- DNS FQDN estável, tempo/NTP correto, firewall segmentado, disco de dados, pacote Java externo homologado e licença/mídia BMC.
- O notebook Windows 16 GB do curso NÃO deve hospedar esta VM Full. A sessão KillerCoda 2 GiB também não serve.
- Em nuvem, o custo da VM/disco/tráfego é separado da autorização BMC. Não criar recursos pagos sem aprovação.

Plano de exemplo (nomes fictícios que você substituirá pelos do seu LAB):
- VM: **ctm-full-lab.exemplo.internal**
- Conta UNIX exclusiva: **ctmuser** (máximo 8 caracteres)
- Grupo: **ctmgrp**
- Home: **/opt/ctmuser**
- Banco: **PostgreSQL fornecido pela BMC** no mesmo host
- Web/API: HTTPS (porta **8443**, se mantida no instalador)
- Sem exposição pública na internet; acesso a portas limitado a VPN/rede administrativa.

**Mídia BMC:** usar https://www.bmc.com/available/edownloads.html (portal BMC EPD), selecionar o pacote **Control-M Full Installation 9.0.27** para Linux x86_64 e GA Point Patches compatíveis; necessita licença/trial e download autorizado. Não usar imagem Docker/ISO de terceiros. O pacote **Server-only NÃO é o Full**.

## Fase 1 — Provisionar a VM com RHEL 9 e conferir dados (somente leitura)

Conecte por SSH a uma VM autorizada e executada com sizing do item anterior:

    cat /etc/os-release
    uname -m
    hostnamectl
    hostname -f
    getent hosts "$(hostname -f)"
    nproc
    free -h
    df -hT
    lsblk -f
    swapon --show
    timedatectl
    ip -br a
    ss -lntp
    java -version 2>&1 || :
    getenforce 2>/dev/null || :

**Critérios:** arquitetura x86_64, >=4 vCPU, >=24 GB RAM, 100 GB disponíveis no volume planejado, sincronismo NTP, hostname/DNS FQDN consistente. Sem isso, NÃO avançar.

O repositório também contém **script read-only** que avalia Server-only com banco local (mínimo 12 GiB), **não substitui a checagem Full 24 GiB**:

    bash sre-killercoda-lab/labs/controlm/precheck-server-linux.sh

## Fase 2 — Preparar SO, Java e conta do produto

**Como administrador da VM RHEL 9** e após validação de política/compatibilidade:

    sudo dnf makecache
    sudo dnf install -y tcsh unzip tar gzip procps-ng iproute \
      bind-utils lsof java-21-openjdk-headless

A versão Java 21 acima é **exemplo de pacote**, não substitui a verificação de *Control-M Compatibility with External Java Vendors*. A BMC exige Java **externo suportado**. Inspecione:

    command -v java
    java -version
    java -XshowSettings:properties -version 2>&1 | grep 'java.home'
    readlink -f "$(command -v java)"

**A conta deve ser exclusiva e estar vazia antes da instalação**. Só execute criação numa VM realmente nova:

    getent group ctmgrp || sudo groupadd ctmgrp
    id ctmuser || sudo useradd -m -d /opt/ctmuser -g ctmgrp -s /bin/tcsh ctmuser
    sudo passwd ctmuser
    sudo chmod 755 /opt/ctmuser
    getent passwd ctmuser
    ls -ld /opt/ctmuser

**Limites de usuário (referências BMC 9.0.27; políticas de SO/PAM podem exigir ajustes):**

    sudo tee /etc/security/limits.d/95-ctmuser.conf >/dev/null <<'LIMITS'
    ctmuser soft nofile 16384
    ctmuser hard nofile 16384
    ctmuser soft nproc 4096
    ctmuser hard nproc 4096
    LIMITS

Depois, abra **nova sessão tcsh de ctmuser** e confira com:

    echo $SHELL
    limit descriptors
    limit maxproc
    echo $HOST

**Importante:** a BMC possui tabela adicional para stacksize, datasize e PostgreSQL kernel parameters conforme Small/Medium/Large. Não copie valores arbitrários de sysctl; use o **CheckReq da própria mídia** para reprovar/aprovar. Não desabilite SELinux nem firewall sem análise.

## Fase 3 — Levar mídia oficial ao servidor e executar CheckReq

No seu computador, baixe a mídia autorizada BMC EPD. O nome de arquivo varia. Copie por SCP/SFTP com SSH, sem colar senhas no chat. Exemplo **somente com arquivo real e host real**:

    scp /CAMINHO_LOCAL/ARQUIVO_BMC_OFICIAL.zip ctmuser@ctm-full-lab.exemplo.internal:/opt/ctmuser/

No servidor, como **ctmuser**:

    cd /opt/ctmuser
    ls -lah
    sha256sum ARQUIVO_BMC_OFICIAL.zip

Compare SHA-256 com hash do portal/fornecedor, quando disponibilizado. Extraia conforme **a extensão real**:

    unzip ARQUIVO_BMC_OFICIAL.zip
    # Para .tar.gz, use: tar -xzf ARQUIVO_BMC_OFICIAL.tar.gz

Verifique a árvore; **não adivinhe caminho**:

    find /opt/ctmuser -type f -name setup.sh -print
    find /opt/ctmuser -type f -name checkReqRun.sh -print

Navegue para o diretório REAL que contém **checkReqRun.sh** e execute (a BMC documenta ONE para Full):

    cd /DIRETORIO_REAL/CheckReq
    ./checkReqRun.sh -product=ONE -memory_model=SMALL -database=PostgreSQL

O CheckReq é parte da mídia oficial e valida sistema/patches/pré-requisitos. Se reportar incompatibilidade, interrompa; corrija o requisito e execute novamente. Não confundir com o script precheck que criamos.

## Fase 4 — Configurar JAVA_HOME na sessão certa

Use conta de instalação do Full, criada com **/bin/tcsh**:

    su - ctmuser

No tcsh:

    setenv BMC_INST_JAVA_HOME /DIRETORIO_REAL_JAVA_HOME
    echo $BMC_INST_JAVA_HOME
    $BMC_INST_JAVA_HOME/bin/java -version

**Exemplo** do fabricante: \`/usr/lib/jvm/temurin-21-jdk\`; não copiar se não existir. O valor deve apontar para pasta contendo **bin/java e release**, não para o executável java.

Se você usar Bash (não recomendado como login shell do proprietário Full/Server sem homologação), a sintaxe seria \`export BMC_INST_JAVA_HOME=...\`. O setenv é específico do tcsh/csh.

## Fase 5 — EXECUTAR instalação FULL da BMC

A instalação não é feita por apt/dnf: **usa os binários proprietários do pacote oficial BMC**.

Na **mesma sessão de ctmuser** e com \`BMC_INST_JAVA_HOME\` definido:

    cd /DIRETORIO_REAL_ONDE_ESTA_SETUP_SH
    ls -l setup.sh
    ./setup.sh

Se o instalador usa GUI, será preciso DISPLAY/X11; use o modo interativo disponibilizado pelo instalador e a orientação oficial para console quando sem sessão gráfica. Não invente flags de instalação em hosts desconhecidos.

**No assistente selecione:**

1. **Control-M 9.0.27 — Full Installation** (não Control-M/Server sozinho).
2. **New installation** de uma conta vazia (não upgrade).
3. **Default / BMC-supplied PostgreSQL** local para primeiro laboratório. Não apontar para PostgreSQL usado pela API de incidentes.
4. Usuário e home de instalação exclusivos, nomes de instância, FQDN e time zone.
5. Portas de EM, Web, Server, Agent e banco: anotar valores reais e evitar conflitos (8443 para Web/API se default).
6. Criar senhas de admins/bancos/serviços e armazenar em cofre, não Git/chat/log.
7. TLS: a BMC habilita SSL por padrão; preferir certificado próprio assinado com **security level 4**. Self-signed security level 2 apenas em lab isolado com plano de substituição.
8. Configurar New Day (padrão documentado: **07:00**); alinhar calendário, fuso e janelas de trabalho. Não mudar arbitrariamente numa produção.
9. **Summary**: conferir todas as escolhas e confirmar instalação.
10. Aguardar sucesso final; não assumir que encerramento do setup equivale a todos os processos operacionalmente prontos.

O arquivo de log oficial da instalação Full:

    $HOME/BMCINSTALL/log/BMC_Control-M_Install_<data-hora>.log

Após executar:

    ls -lth $HOME/BMCINSTALL/log/ | head -20
    grep -Ein 'ERROR|FAIL|EXCEPTION|WARNING' $HOME/BMCINSTALL/log/BMC_Control-M_Install_*.log | tail -80

Erros podem aparecer em mensagens históricas mesmo num setup finalizado; leia o contexto e o status final.

### Fase 5B — Instalação silenciosa (somente DEPOIS de gerar XML)

Na interface do próprio instalador:
1. Escolha **Full Installation** e preencha as telas.
2. Pare na **Summary**.
3. Clique **Generate** para criar XML oficial.
4. Saia sem instalar e proteja o XML (pode conter dados sensíveis).
5. Como ctmuser, execute:

    chmod 600 /CAMINHO/params-full.xml
    /DIRETORIO_REAL_ONDE_ESTA_SETUP_SH/setup.sh -silent /CAMINHO/params-full.xml

Não escreva XML de parâmetros à mão usando nomes inventados, nem passe senhas diretamente na linha de comando (histórico/processos). Use fluxo de proteção de segredos da BMC.

## Fase 6 — Verificar componentes: EM, Server, Agent, DB

Abra **nova sessão de login** com o proprietário Full para inicialização de ambiente do produto:

    su - ctmuser
    hostname -f
    date -Is
    ps -ef | grep -Ei 'control.m|ctm|postgres|java|kafka' | grep -v grep
    ss -lntp
    df -h
    free -h
    ls -lth $HOME/BMCINSTALL/log/ | head -20
    command -v start_server
    command -v start-ag
    command -v ctm_menu
    command -v ctmpsm

**Não conclua que serviço está saudável apenas porque há processo/listener.** Se comandos não estiverem no PATH, confira o layout de binários da instalação e os perfis da conta; não instale pacotes arbitrários.

**Agent local:** ele faz parte do Full e do Server. Para iniciá-lo manualmente, caso não esteja ativo e após verificar status, como usuário apropriado:

    start-ag

O utilitário start-ag é oficial; verifique se o comando existe e a localização documentada na mídia. Para diagnóstico:

    ag_diag_comm

Control-M/EM e Control-M/Server têm utilitários de inicialização e menus próprios. Use os procedimentos pós-instalação da versão e não crie serviços systemd antes de observar como EM/Server já são gerenciados.

**Web:** teste em rede privada com HTTPS e FQDN, **somente se a porta 8443 for a instalada**:

    https://ctm-full-lab.exemplo.internal:8443

No host:

    ss -lntp | grep ':8443'
    openssl s_client -connect ctm-full-lab.exemplo.internal:8443 -servername ctm-full-lab.exemplo.internal </dev/null

No navegador: verificar certificado, login administrativo criado no instalador e status do Control-M/Server/Agent. A configuração exata do endpoint depende da mídia/porta escolhida. Não abrir Web/API para toda Internet nem forçar bypass de TLS.

**Firewall:** controlar por origem/destino/protocolo; exemplos de portas BMC: 8443 Web/API; 2369 Server Configuration Agent; 2370 gateway EM-Server; 7005/7006 para comunicação TCP Agent/Server ou 11443/10443 em modalidade HTTPS. Nem todas serão necessárias simultaneamente. Não desabilitar firewall/SELinux, nem liberar 0.0.0.0/0.

## Fase 7 — Configuração inicial no Control-M Web

No navegador autenticado na rede de gestão, a ordem didática:

1. **Configuration → Control-M/Servers:** verificar que o Server local foi identificado e está **Up**. Em Full ele pode ser registrado pelo instalador; não duplique registro se existente.
2. **Configuration → Agents:** verificar Agent local associado e executando. Usar opção Test/Ping conforme a interface.
3. **Security → Roles/Users:** criar perfil técnico mínimo para job e administrador de laboratório; não conceder Admin a todos.
4. Ajustar **Time Zone** e **New Day Time** em conformidade com calendário real. O New Day de referência começa **07:00** por padrão, não necessariamente meia-noite.
5. **Planning → Workspace/Folder:** criar pasta \`SRE_LAB\`, job \`JOB_01_PRECHECK\`, tipo **Command**, comando **\`/usr/bin/date -u\`**, Agent local e \`RunAs\` = usuário UNIX de laboratório permitido (não usar \`workbench\` se ele não existir).
6. Criar \`JOB_02_PROCESSAMENTO\` com **\`/usr/bin/printf 'OK\n'\`** e dependência do JOB 01; job 03 de validação com nova dependência; salvar, validar e executar em janela de teste.
7. **Monitoring:** verificar estados (Waiting/Executing/Ended OK), Output, código de retorno e timestamps; registrar evidência.
8. Falha controlada em job separado **\`/bin/sh -c 'exit 42'\`**; verificar Ended Not OK, output, alerta, dependência e política autorizada de rerun. Nunca simular em ambiente produtivo.

**Cuidado:** comandos de saída simples diferem de jobs com dados. Não reaplicar rerun sem considerar idempotência, dependências e execução parcial.

## Fase 8 — Pós-instalação, backup e segurança

Para laboratório, documentar e conferir:
- snapshots e backup/restauração do banco Control-M via utilitário oficial/ctm_menu, não simplesmente copiar a pasta de dados com PostgreSQL ativo;
- teste de restauração em VM clone (sem ativos produtivos);
- inventário de versão/patch, contas e certificados; ativar logging/monitoramento e política de retenção;
- rotina de start/stop em systemd **documentada pela BMC** para EM e Server separadamente, só depois de identificar scripts e usuário corretos;
- definir calendário de aplicação e New Day, registro/monitoramento de Agents;
- aplicar **GA Point Patches** homologados depois do base, conforme documentação BMC;
- não usar Trial Full como produção: a BMC explica que trial precisa ser desinstalado antes de instalar edição não-trial para uso produtivo.

## Fase 9 — Variante de PRODUÇÃO: instalação distribuída

**Preferência para a vaga empresarial que exige administração completa:**

- **VM-EM (>= especificação BMC EM + banco):** conta UNIX própria \`ctmem\`, instalar Java externo, executar CheckReq com \`-product=EM\`, executar mídia \`./setup.sh\` e escolher **Control-M/Enterprise Manager**. Verificar EM Web/API, PostgreSQL e configuração TLS.
- **VM-SERVER (>= especificação BMC Server + banco):** conta \`ctmsrv\`, CheckReq \`-product=CTMS\`, mídia \`./setup.sh\`, escolher **Control-M/Server**. O **Agent local vem junto**; iniciar e testar.
- **VM-AGENT externa (opcional):** instalar Control-M/Agent no Windows ou Linux usando mídia autorizada, conexão e permissões compatíveis. Testar \`start-ag\`, \`ag_diag_comm\`, firewall e registrar Agent no Server.
- No EM: **Configuration → Control-M/Servers → Add Server**, fornecer FQDN Server, ID e portas reais de Configuration Agent/EM; conectar. Conferir status.
- Criar job **/usr/bin/date -u** no Agent para testar fluxo; configurar calendário, timezone, TLS, perfis mínimos, backup/restore, monitoramento e alta disponibilidade conforme necessidade.

**A instalação distribuída em 2 VMs é suficiente para início** porque o Server já instala Agent local; 3ª VM apenas para exercitar Agent externo/Windows.

## Fase 10 — Problemas e como diagnosticar

| Sintoma | Hipóteses comuns | Evidência |
|---|---|---|
| CheckReq falhou | RAM, SO, biblioteca, kernel, swap, Java | saída CheckReq e Release Notes |
| setup.sh não inicia | DISPLAY, conta/shell, permissão, Java, mídia | log em BMCINSTALL/log |
| EM indisponível | listener Web/API, cert/TLS, DB, Java | ss, openssl, logs EM |
| Server Down/Disconnected | processo, PostgreSQL, DNS, portas, TLS | ctm_menu, ctmpsm, logs Server |
| Agent Unavailable | nome host, rota, certificados, RunAs | ag_diag_comm, logs Agent |
| Job Ended Not OK | exit code, script, permissão, DB | Output, STDERR/STDOUT e log |
| Job Waiting | predecessor, recurso, calendário, New Day | Planning/Monitoring e status dos jobs |
| Falha pós-upgrade | dados, DB, schema, Java, patch, rollback | backups/versões/logs; suporte BMC |

**Não executar automaticamente:** reset de banco, \`shutdb\`, \`shut_ctm\`, \`rm -rf\` de diretório de instalação, desabilitar SELinux/Firewall, baixar instalador não autorizado ou cancelar New Day em produção.

## Links oficiais utilizados

- [Installation/planejamento](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Introduction_to_Control-M_Installation.htm)
- [Full Linux installation](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Installing_Control-M_on_UNIX.htm)
- [Full Requirements](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_full_installation_system_requirements.htm)
- [Pre-installation/CheckReq](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_pre-installation_procedures_on_UNIX.htm)
- [External Java](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Java_Installation.htm)
- [Post-installation Linux](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Post-installation_Procedures_on_UNIX.htm)
- [Agent start/stop diagnostics](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Agent_Troubleshooting_Utilities.htm)
- [New Day](https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/New_Day_Procedure.htm)
- [BMC downloads EPD](https://www.bmc.com/available/edownloads.html)

**Validação:** estas instruções foram montadas a partir da documentação da BMC e dos laboratórios anteriores, não são um registro de instalação executada. Antes de aplicar, confirmar versão real do pacote, distribuição Linux e direitos de acesso; cada saída do ambiente real condiciona a etapa seguinte.
