# Manual Operacional — Instalação e configuração do BMC Control-M/Server em Linux

**Edição 1.0 | 14/11/2026 | Referência: Control-M 9.0.27 | Ambiente: LAB autorizado**  
**Escopo:** Control-M/Server autogerenciado em servidor Linux x86_64, PostgreSQL fornecido pela BMC, Agent local, conexão a Control-M/EM em outro servidor; roteiro alternativo para instalação Full apenas como laboratório.

> **ATENÇÃO:** este é um roteiro técnico de instalação REAL, não um instalador nem um substituto da documentação/licença BMC. Os procedimentos foram confrontados com a documentação BMC 9.0.27. Os parâmetros concretos (rede, conta, JRE, recursos, caminho, hostname, portas, certificado) precisam ser homologados no destino. Nenhum software proprietário foi baixado ou instalado neste curso. Não executar em produção sem mudança aprovada, backups e autorização.

## 1. Entenda o que será instalado

    Control-M/EM (VM independente / console Web / CCM)
           | integração segura, status, cadastro de hosts
    Control-M/Server 9.0.27 (VM Linux desta instalação)
           | scheduler, New Day, calendário e dependências
           | PostgreSQL dedicado fornecido pela BMC
           | Control-M/Agent LOCAL incluído — NÃO remover
           |
        Agents externos Linux e Windows
           | jobs Shell, Batch, SQL, integrações cloud

**Diferenças:**
- **EM:** centraliza administração, usuários, monitoramento e configuração.
- **Server:** engine de agendamento, ordens de execução, filas e dependências; comunica-se com EM e Agents.
- **Agent:** recebe/executa jobs e devolve status; o instalador Server já instala um Agent local obrigatório.
- **Banco de dados:** guarda informações do Control-M/Server. Não reutilize o PostgreSQL de exercícios de incidentes; escolha a instalação PostgreSQL BMC do próprio produto ou um banco externo homologado.
- **Control-M/Server sozinho NÃO instala a interface Control-M/EM.** Para administração visual central, instalar EM à parte ou usar Full Installation com recursos e licença apropriados.

A BMC recomenda a **arquitetura distribuída em produção**. A instalação Full concentra EM + Server no mesmo host/conta e destina-se preferencialmente a testes, pois acopla backup e manutenção.

## 2. Dimensionamento suportado — versão 9.0.27

| Componente | vCPU | RAM mínima do modelo Small | Disco de instalação |
|---|---:|---:|---:|
| Control-M/Server **sozinho**, banco externo | 4 | 8 GB | 40 GB |
| Control-M/Server + PostgreSQL BMC no mesmo host | 4 | **12 GB** (8 + 4 GB) | 40 GB |
| Control-M/EM (separado; PostgreSQL BMC) | 4 | **20 GB** | 60 GB |
| **Full Installation** EM + Server | 4 | **20 GB + 4 GB** quando banco local | **100 GB** |

> Estes valores são mínimos publicados, não um tamanho ideal de produção. Reserve espaço adicional para instalador, logs, WAL, backups e swap conforme BMC. A BMC recomenda swap em disco da ordem de 1,5 × a RAM. Para laboratório de Server com banco local, proponho **4 vCPU, 16 GB RAM e 80–100 GB de volume** para folga, mas esta última é **uma recomendação de projeto**, não mínimo oficial.

**Impacto no seu ambiente:** um notebook Windows de 16 GB **não comporta de forma confortável** uma VM de 12–16 GB com PostgreSQL e o próprio Windows. O KillerCoda de ~2 GiB também não comporta. Para o projeto completo, use servidor/VM dedicado ou nuvem, depois de avaliar custos e obter licença/instalador BMC. Linux RHEL 9 x86_64 é a plataforma usada neste roteiro; validar sistema operacional e patches nas notas de compatibilidade 9.0.27 antes de provisionar.

## 3. Planejamento obrigatório antes de tocar na VM

Registre valores reais (exemplos NÃO são configurações para copiar cegamente):

| Variável | Exemplo para LAB | Finalidade |
|---|---|---|
| Host Server | ctm-srv-lab.exemplo.interno | DNS/FQDN resolvível |
| Host EM | ctm-em-lab.exemplo.interno | Gestão central; exige outra instalação |
| Host Agent externo | ctm-agent-lab.exemplo.interno | Execução remota opcional |
| Conta UNIX Server | ctmuser | Exclusiva, até 8 caracteres |
| Grupo UNIX | ctmgrp | Grupo administrativo do produto |
| Home do Server | /opt/ctmuser | Diretório da conta em volume dimensionado |
| Banco | PostgreSQL fornecido pela BMC | Instalação padrão do assistente |
| Java | Java externo homologado | BMC_INST_JAVA_HOME |
| Protocolo | TLS/SSL | Preferir certificado de CA da organização |
| Meio de distribuição | BMC EPD | Download autorizado |

**Checklist de decisão:** ambiente isolado? licenciamento/trial BMC obtido? host atende 4 vCPU, 12 GB, 40 GB? backup e DNS prontos? portas restritas? janela de mudança? versão suportada? certificado gerido? Nunca usar IPs de Pod ou nomes transitórios do KillerCoda como endpoints persistentes.

## 4. Pré-instalação — inspeção sem alterar a VM

**Conecte via SSH ao RHEL 9 autorizado** e execute como usuário com permissão de leitura:

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
    chronyc tracking
    ip -br a
    ss -lntp
    systemctl is-active firewalld
    getenforce
    rpm -qa | grep -Ei 'java|tcsh|libnsl|glibc' | sort

Valide: arquitetura x86_64, horário sincronizado, resolução bidirecional de DNS, hostname persistente, disco livre, portas não usadas, SO e bibliotecas compatíveis, SELinux mantido conforme política. Não desative firewall/SELinux para instalar.

**Inspeção do perfil UNIX:**

    id ctmuser
    getent group ctmgrp
    grep -R "^ctmuser" /etc/security/limits.conf /etc/security/limits.d 2>/dev/null

É normal o usuário ainda não existir na VM limpa.

## 5. Preparação do RHEL — comandos com privilégios

**Executar como root/sudo SOMENTE na VM dedicada e depois da homologação.**

Primeiro atualize os repositórios corporativos e instale ferramentas usuais (pacotes variam pela imagem/RHEL):

    sudo dnf makecache
    sudo dnf install -y tcsh unzip tar gzip procps-ng bind-utils \
      iproute net-tools lsof java-21-openjdk-headless

**Java:** o Control-M exige JRE/JDK externo. Java 21 é mostrado como exemplo na documentação BMC 9.0.27, mas valide fornecedor e versão na matriz de compatibilidade e no repositório autorizado antes de seguir. Não use Java que veio junto com algum produto não suportado.

Conta exclusiva (se ainda não existir):

    sudo groupadd ctmgrp
    sudo useradd -m -d /opt/ctmuser -g ctmgrp -s /bin/tcsh ctmuser
    sudo passwd ctmuser
    sudo chmod 755 /opt/ctmuser
    getent passwd ctmuser
    ls -ld /opt/ctmuser

Se grupo/usuário já existir, **não recrie** nem altere UID/GID sem verificar a propriedade dos dados. A documentação BMC 9.0.27 permite para Control-M/Server shells csh/tcsh; evite usar /bin/bash como shell principal dessa conta sem validação do fabricante.

Exemplo de limites de arquivos e processos; verifique os limites agregados de todos os serviços e as políticas de PAM antes de aplicar:

    sudo tee /etc/security/limits.d/95-ctmuser.conf > /dev/null <<'LIMITS'
    ctmuser soft nofile 16384
    ctmuser hard nofile 16384
    ctmuser soft nproc 4096
    ctmuser hard nproc 4096
    LIMITS

Depois abra nova sessão da conta e confira:

    sudo -iu ctmuser
    limit descriptors
    limit maxproc
    exit

**Atenção:** a BMC exige especificamente 16.384 file descriptors para o usuário do Control-M e descreve outras recomendações para stack/datasize. Não aplique valores de sysctl de PostgreSQL sem identificar o porte e a existência de outros bancos; a documentação apresenta tabelas diferentes para S/M/L. Use o CheckReq do próprio instalador e o DBA para corrigir apenas os itens indicados.

Localize a instalação real do Java:

    command -v java
    readlink -f "$(command -v java)"
    java -version

No RHEL, confirme o diretório real de JAVA_HOME, por exemplo /usr/lib/jvm/java-21-openjdk; **não invente um caminho**. O diretório JAVA_HOME deve conter bin/java.

## 6. Download autorizado do Control-M 9.0.27

A BMC distribui os pacotes via Electronic Product Distribution (EPD), sujeitos a conta, contrato ou trial autorizado:

**https://www.bmc.com/available/edownloads.html**

No EPD escolha **Control-M/Server for UNIX and Microsoft Windows** da versão/patch contratados, plataforma Linux x86_64. Para uma instalação Full, a seleção é **Control-M/Enterprise Manager / Full Installation**, não o pacote Server-only.

Transfira o arquivo oficial para uma pasta privada da VM, por exemplo /var/tmp/bmc-stage. Não exponha chaves, senhas ou token BMC em shell history/chat/Git.

    sudo mkdir -p /var/tmp/bmc-stage
    sudo chown ctmuser:ctmgrp /var/tmp/bmc-stage
    sudo chmod 700 /var/tmp/bmc-stage

Depois do upload autorizado, como ctmuser:

    cd /var/tmp/bmc-stage
    ls -lh
    sha256sum NOME_REAL_DO_ARQUIVO_BMC

Compare o checksum com o disponibilizado no portal BMC, se houver. **Substitua NOME_REAL_DO_ARQUIVO_BMC pelo nome recebido**; não existe URL pública universal que faça esse download sem autorização.

Extraia conforme a extensão REAL:

    # Exemplos condicionais; execute apenas o que combinar com seu arquivo.
    tar -xf ARQUIVO_OFICIAL.tar
    # OU
    tar -xzf ARQUIVO_OFICIAL.tar.gz
    # OU
    unzip ARQUIVO_OFICIAL.zip

Verifique os arquivos reais após extrair:

    find /var/tmp/bmc-stage -maxdepth 5 -type f -name setup.sh -print
    find /var/tmp/bmc-stage -maxdepth 5 -type f -name checkReqRun.sh -print

Copie o conjunto extraído para um diretório privado acessível ao ctmuser se o pacote exigir instalação a partir do HOME; não copie apenas setup.sh sem seus subdiretórios.

## 7. CheckReq e Java antes de instalar

A BMC fornece a ferramenta **CheckReq** dentro da mídia, que também é executada durante o instalador. No diretório real CheckReq:

    cd /CAMINHO_REAL_DA_MIDIA/CheckReq
    chmod u+x checkReqRun.sh
    ./checkReqRun.sh -product=CTMS -memory_model=SMALL -database=PostgreSQL

Conforme as instruções oficiais, CTMS indica Control-M/Server; SMALL indica porte; PostgreSQL indica banco. Se a versão recebida usar outra grafia no parâmetro, use o help desse pacote.

Não ignore uma reprovação de SO, biblioteca, memória, disco ou patch. Corrija e execute CheckReq novamente antes de continuar.

**Java na sessão de instalação da conta tcsh:**

    su - ctmuser
    setenv BMC_INST_JAVA_HOME /CAMINHO_REAL_DO_JAVA_HOME
    echo $BMC_INST_JAVA_HOME
    $BMC_INST_JAVA_HOME/bin/java -version

Use a MESMA sessão tcsh para abrir setup.sh. Não copie o caminho de exemplo sem confirmar.

## 8. Instalação interativa real: Control-M/Server

Entre no diretório da mídia, como usuário ctmuser, após CheckReq aprovado:

    cd /CAMINHO_REAL_DA_MIDIA
    chmod u+x setup.sh
    ./setup.sh

O instalador pode abrir GUI se DISPLAY e XServer estiverem disponíveis; em host sem interface, use modo de console oferecido pelo próprio instalador. **Não force flags de console não verificadas neste manual.**

**Passo a passo das escolhas no assistente:**

1. Produto: **Control-M/Server** (não selecionar Full Installation para esta VM dedicada apenas ao Server).
2. Validação de pré-requisitos: corrigir todos os erros antes de prosseguir.
3. Conta e HOME: selecionar ctmuser e /opt/ctmuser, conforme mídia e política.
4. Banco: escolher **dedicated BMC-supplied PostgreSQL** para o primeiro laboratório, sem instalar PostgreSQL manualmente. Alternativa Custom exige DB externo homologado e DBA.
5. Hostname, instância e portas: informar FQDN estável e conferir conflitos com ss/Firewall. **Não supor que todos os defaults serão idênticos**.
6. Protocolo: para versão 9.0.27 o padrão é SSL/TLS. Preferir certificado corporativo assinando Security Level 4; self-signed de nível 2 é menos seguro e deve ser substituído.
7. Senhas: gerar e registrar em cofre; não reutilizar senhas de laboratório; nunca salvá-las em repositórios.
8. Resumo: registrar portas, caminhos, versão, nome do Control-M/Server, banco e IDs; verificar antes de confirmar.
9. Instalar e revisar mensagem de sucesso e arquivos de log.
10. Iniciar e validar o **Agent local que vem no Server**. **Nunca removê-lo**: BMC alerta que é componente crítico.

**Log de instalação documentado pela BMC:**

    $HOME/BMCINSTALL/log/BMC_Control-M_Server_<data-hora>.log

Como ctmuser após instalar:

    ls -lth "$HOME"/BMCINSTALL/log/ | head -20
    grep -Ein 'error|failed|warning|exception' "$HOME"/BMCINSTALL/log/BMC_Control-M_Server_*.log | tail -80

Resultado do grep não é diagnóstico conclusivo: leia o contexto e o status final do instalador. Se houver erro de instalação, preserve evidências e corrija a causa antes de repetir.

## 9. Instalação silenciosa para padronização

**Não invente manualmente o XML.** A BMC instrui gerar o arquivo de parâmetros pelo instalador GUI/console, até a tela Summary, usando Generate, depois sair sem instalar. Proteja esse XML como potencial segredo.

Padrão oficial da instalação **Server**:

    /CAMINHO_REAL_DA_MIDIA/Setup_files/components/ctm/setup.sh \
      -silent /CAMINHO_PRIVADO/params-server.xml

Para Java explícito, a BMC também documenta:

    /CAMINHO_REAL_DA_MIDIA/Setup_files/components/ctm/setup.sh \
      -silent /CAMINHO_PRIVADO/params-server.xml \
      -BMC_INST_JAVA_HOME /CAMINHO_REAL_DO_JAVA_HOME

Permissões recomendadas para o arquivo com parâmetros:

    chmod 600 /CAMINHO_PRIVADO/params-server.xml

A BMC possui opção -encrypt para senhas, mas **não cole senha em argumento de comando**: ela pode aparecer no histórico/listagem de processos. Use o assistente ou procedimento corporativo de proteção de segredos.

## 10. Subir e validar serviços do Control-M/Server

Após instalação, **como ctmuser**:

    echo "$HOME"
    ls -ld "$HOME/ctm_server" "$HOME/BMCINSTALL"
    command -v ctm_menu
    command -v ctmpsm
    ctm_menu

Use ctm_menu para configurar/inspecionar parâmetros de comunicação, banco e manutenção. A BMC documenta também ctmpsm (Production Support Menu):

    ctmpsm

Para processos e sockets no Linux, sem intervenção:

    ps -ef | grep -Ei 'ctm|control.m|kafka|zookeeper|postgres' | grep -v grep
    ss -lntp
    df -h
    free -h

**Subida via Control-M/EM:** Configuration > Control-M/Servers > selecionar servidor > Desired State > Up. Isso solicita ao Configuration Agent iniciar serviços. Para reinicialização administrada, use Desired State > Recycle; para parar, Desired State > Down. Em ambiente real, agende mudança e confirme jobs em execução antes de intervir.

**Autostart no systemd:** A BMC 9.0.27 documenta modelo específico para RHEL 8/9/10 e outros sistemas, usando:

    /opt/ctmuser/ctm_server/data/rc.ctmuser

e comandos de parada:

    /opt/ctmuser/ctm_server/scripts/shut_ca
    /opt/ctmuser/ctm_server/scripts/shut_ctm -CA
    /opt/ctmuser/ctm_server/scripts/shutdb
    /opt/ctmuser/ctm_server/scripts/shut_kafka

**Esses nomes/caminhos devem existir na instalação real.** Não crie service customizado antes de validar scripts e conteúdo exato da documentação do produto. Para habilitar uma unit validada:

    sudo systemctl daemon-reload
    sudo systemctl enable CtmServer.service
    sudo systemctl status CtmServer.service --no-pager
    sudo journalctl -u CtmServer.service -n 100 --no-pager

Não use systemctl start/stop indiscriminadamente se o produto estiver gerenciado por cluster/HA ou por outra automação. Não reinicie a VM simplesmente para provar instalação sem validar jobs e janelas.

## 11. Rede, firewall e TLS

**Defaults publicados para Control-M 9.0.27** (confirmar durante instalação e com ctm_menu/ctmagcfg; não abrir todas indiscriminadamente):

| Porta | Uso de referência |
|---|---|
| 2369/TCP | Configuration Agent do Server |
| 2370/TCP | Comunicação EM / Server |
| 7005/TCP | Agent → Server, modo TCP |
| 7006/TCP | Server → Agent, modo TCP |
| 11443/TCP | Agent → Server, variante HTTPS |
| 10443/TCP | Server → Agent, variante HTTPS |
| 2368/TCP | HA, se implementada |
| 8393/TCP | API-Gateway, se implementado |

A documentação lista alternativas TCP/HTTPS; **não presuma que 7005/7006 e 11443/10443 sejam todos obrigatórios simultaneamente**. Abra apenas portas do protocolo escolhido, origem e destino específicos, no firewall local e Security Groups/NSG da nuvem.

Na VM Server:

    ss -lntp | grep -E ':(2369|2370|7005|11443|8393)\b'
    sudo firewall-cmd --list-all

Do Agent/EM, conforme conectividade e autorização:

    getent hosts ctm-srv-lab.exemplo.interno
    nc -vz ctm-srv-lab.exemplo.interno 2369
    nc -vz ctm-srv-lab.exemplo.interno 11443

**Exemplos acima usam FQDN fictício**; substitua. Se falhar, verifique DNS, rota, listener, firewall/NSG e certificado; NÃO desative TLS ou abra 0.0.0.0/0 para forçar sucesso.

Control-M 9.0.27 inicia com SSL habilitado nas novas instalações. Em produção, configure certificados com CA e SubjectAltName compatível, nível de segurança 4; mantenha trilha de renovação.

## 12. Vincular o Server ao Enterprise Manager

**Pré-requisito:** Control-M/EM real e funcional instalado separadamente ou serviço central já disponível. Server-only não fornece o EM.

Na interface Control-M Web / Configuration:

1. Abrir **Configuration > Control-M/Servers**.
2. Clicar **Add Server**.
3. Escolher descoberta automática, quando disponível; caso necessário, manual.
4. Preencher **Name** lógico sem caracteres proibidos, **Host** com FQDN, **ID** único de três caracteres.
5. Definir **Configuration Agent Port** (padrão 2369) e **Control-M/EM Port** (padrão 2370), e protocolo/tipo de TLS compatível.
6. Configurar time zone e New Day Time de acordo com negócio (horário de "New Day" NÃO é simplesmente meia-noite).
7. Validar conectividade e concluir **Add/Manage**.
8. Conferir **Desired State=Up** e **Actual State=Up**, sincronização e Services sem alarmes.

A BMC alerta que alguns parâmetros de horário não podem ser alterados enquanto o Server está managed; trate New Day/Time Zone como mudança controlada.

## 13. Vincular Agents e executar primeiro job

O pacote Server já entrega um **Agent local necessário**. Para um Agent externo, instale o pacote oficial no Linux/Windows de destino, configure o servidor primário e comunicação TLS, e registre em:

**Configuration > Agents > Add Agent > preencher Server, hostname, portas/protocolo > Test > Add.**

No Agent Linux (com o usuário de instalação), ferramenta de configuração documentada:

    ctmagcfg

**Primeiro job de laboratório no Control-M Web:** Planning > criar workspace/Folder > criar Job:Command no Agent registrado, usar comando sem efeitos:

    /usr/bin/date -u

Configurar RunAs como usuário com permissão para executar o comando, calendário de teste, janela de execução e parâmetros; definir sequência com outro job, fazer Check-in/Deploy no ambiente de LAB e executar **somente se o scheduler estiver de fato autorizado**. Em Monitoring, observar estados, output, código de retorno e dependências. Nunca rodar job de teste numa fila produtiva sem saber o impacto.

## 14. Troubleshooting por sintoma — operação autônoma

| Sintoma | Primeiro diagnóstico | Próxima ação com controle |
|---|---|---|
| Server não sobe | logs instalação, proclog, java -version, espaço, portas | corrigir requisito identificado |
| EM indica Disconnected | DNS/ports 2369/2370, certificado/TLS, processo CA | corrigir rede/truststore/configuração |
| Agent Unavailable | ctmagcfg, DNS, rotas/portas 7005/7006 ou HTTPS, relógio | validar listener e hostname autorizado |
| Job END NOTOK | output, exit code, RunAs, permissões e recursos | corrigir causa e avaliar rerun/idempotência |
| Job WAIT | dependências, calendário, condição, recursos e New Day | validar predecessor/sem forçar indevidamente |
| Falha PostgreSQL | status de serviços DB, espaço/WAL, portas/credenciais | diagnosticar DB com DBA antes de restaurar |
| Lentidão | CPU/RAM/IO, contagem de jobs, logs e backlog | capacity/ajustes via processo de mudança |
| SSL handshake | cadeia de CA, SAN, truststore, vencimento, relógio | renovar/importar certificados corretamente |

Coleta somente leitura:

    date -Is
    hostname -f
    uptime
    df -h
    free -h
    ss -lntp
    ps -ef | grep -Ei 'ctm|java|postgres|kafka' | grep -v grep

O fabricante indica logs de processos do Server em **$CONTROLM_SERVER/proclog** e logs de banco PostgreSQL em **pgsql/data/pg_log** (caminhos relativos à instalação). Não apague proclog ou WAL sem política de retenção, backup e suporte.

Usar ctm_menu para manutenção e ctmpsm para Production Support Menu; antes de usar opções de remoção ou reset de dados, confirme exatamente o efeito do subcomando.

## 15. Backup, contingência, recuperação

**Backup diário é recomendado pela BMC.** O procedimento depende de banco BMC dedicado vs externo:

- **Hot backup** do PostgreSQL fornecido pela BMC: requer archive mode e armazenamento de arquivos de archive; backup com Server ativo.
- **Cold backup:** exige desligamento do Server e archive mode desligado, com janela operacional.
- **Restore/rebuild:** ação de alto impacto que pode retroceder estados de jobs e banco; só após aprovação, evidências, consistência de versão e teste isolado.
- Inclua cópias de definição de jobs, certificados, configurações, tokens de integração em cofre, parâmetros de comunicação, mídia instaladora, versão/patch e processo de recuperação documentado. Não copiar senhas em texto claro para Git.

Na conta ctmuser:

    ctm_menu

Para hot backup do PostgreSQL BMC dedicado: **Maintenance > Backup Database**, escolher modo Hot conforme prompts; antes habilitar Archive Mode em Database Utilities conforme documentação. O menu exato pode variar com a versão/opção; siga o próprio produto.

**Plano de retorno a serviço após incidente:** confirmar causa → escolher intervenção mínima → validar DB/Server/EM/Agent → testar job inofensivo → liberar fluxos pendentes com controle de duplicidade → registrar horários, evidências, impacto e ações.

## 16. Upgrade/migração 9.0.27 e rollback

Segundo a documentação oficial, para **upgrade de Control-M/Server 9.0.27** o ponto de partida suportado é **9.0.21.300 ou superior**; **atualizar EM antes do Server**. Para versões mais antigas, planejar etapas intermediárias de migração compatíveis, sem improvisar upgrade in-place.

**Runbook mínimo:**
1. Inventariar versões/patches de EM, Server, Agents, DB, Java e plug-ins; levantar compatibilidade cruzada.
2. Congelar mudanças, revisar calendários e jobs críticos; preparar rollback e comunicação.
3. Realizar e **testar restauração** dos backups do Server e EM em clone isolado; registrar versão e estado dos bancos.
4. Obter pacote 9.0.27 e GA Point Patches no EPD autorizado; comparar integridade.
5. Executar CheckReq na origem/destino; validar espaço, bibliotecas, JRE externa, certificados.
6. Atualizar **Control-M/EM primeiro**; validar gestão.
7. Atualizar **Control-M/Server depois** pelo instalador oficial; seguir notas de upgrade/HA.
8. Atualizar Agents e plug-ins conforme matriz de compatibilidade e janelas.
9. Conferir CA, gateway, Server, DB, Agents, New Day, calendário, execuções e histórico.
10. Caso falhe, **não faça downgrade improvisado de banco**: seguir documentação de downgrade/restore aplicável ao release e acionar suporte BMC.

Para múltiplas instalações iguais, a opção **-silent XML** exige arquivo gerado oficialmente e protegido.

## 17. Checklist de aceite e lições aprendidas

| Critério | Evidência esperada |
|---|---|
| OS/FQDN compatíveis | CheckReq aprovado; DNS e timezone corretos |
| Conta e disco | ctmuser exclusivo; ulimit/persistência validados |
| Java | BMC_INST_JAVA_HOME válido e versão homologada |
| Produto | Control-M/Server 9.0.27 instalado; log sem falha bloqueante |
| Banco | PostgreSQL BMC ativo e com backup configurado |
| Agent local | Presente e operacional |
| EM | Registro do Server; Desired/Actual State Up |
| Agents externos | Test de comunicação OK |
| Job teste | END OK e output coerente |
| TLS | Certificados e comunicação verificados |
| Suporte e reversão | Procedimentos, evidências, backups e contatos registrados |

**Não instalado neste laboratório até a data de criação:** não afirmar que a VM, o Server, EM ou Agent BMC estão funcionando antes de ter binários autorizados, instalação real e evidências de execução. A simulação Shell/KillerCoda anterior apenas ensina lógica dos jobs.

## 18. Fontes BMC 9.0.27 e links operacionais

1. Instalação e arquitetura: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Introduction_to_Control-M_Installation.htm
2. **Control-M/Server**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Installation.htm
3. **Pré-requisitos Linux**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_pre-installation_procedures_on_UNIX.htm
4. **Full Installation, recursos**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_full_installation_system_requirements.htm
5. **Java externo**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Java_Installation.htm
6. **Firewall/Portas**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Firewall.htm
7. **Gestão de Server no EM**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Management.htm
8. **Agentes**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Agents.htm
9. **Backup e Restore**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Control-M_Server_Database_Backup_and_Restore.htm
10. **Upgrade**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Server_Upgrade.htm
11. **Logs e manutenção**: https://documents.bmc.com/supportu/9.0.27/en-US/Documentation/Database_Maintenance_and_Cleanup.htm
12. **Portal de download autorizado**: https://www.bmc.com/available/edownloads.html

**Observações finais:** as notas online da BMC podem mudar; valide sempre os instaladores e as Release Notes associadas ao contrato/patch efetivo. Este manual não ensina contornar licenças. Para avaliação, solicite Trial Full oficial e hardware apropriado.
