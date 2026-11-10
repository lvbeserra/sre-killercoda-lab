# LAB DE INFRAESTRUTURA SENIOR — WINDOWS SERVER / AD / HYPER-V
# Inventario SOMENTE LEITURA. Executar apenas em maquinas autorizadas.
# Pode funcionar em Windows PowerShell 5.1+; comandos opcionais dependem do host.
# Nao altera sistema, nao reinicia servicos, nao faz export de credenciais.

$ErrorActionPreference = 'Continue'

Write-Host "=== 1. IDENTIFICACAO E SISTEMA OPERACIONAL ===" -ForegroundColor Cyan
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, BuildNumber, LastBootUpTime, TotalVisibleMemorySize, FreePhysicalMemory |
    Format-List

Write-Host "=== 2. DOMINIO, HARDWARE E CPU ===" -ForegroundColor Cyan
Get-CimInstance Win32_ComputerSystem |
    Select-Object Name, Domain, PartOfDomain, Manufacturer, Model, TotalPhysicalMemory, NumberOfLogicalProcessors |
    Format-List
Get-CimInstance Win32_Processor |
    Select-Object Name, NumberOfCores, NumberOfLogicalProcessors |
    Format-Table -AutoSize

Write-Host "=== 3. VOLUMES (CAPACIDADE E ESPACO LIVRE) ===" -ForegroundColor Cyan
try {
    Get-Volume | Select-Object DriveLetter, FileSystemLabel, FileSystem,
        @{Name='TotalGB';Expression={[math]::Round($_.Size/1GB,2)}},
        @{Name='LivreGB';Expression={[math]::Round($_.SizeRemaining/1GB,2)}} |
        Format-Table -AutoSize
} catch { Write-Warning "Nao foi possivel consultar Get-Volume: $($_.Exception.Message)" }

Write-Host "=== 4. ADAPTADORES DE REDE (SEM DADOS DE AUTENTICACAO) ===" -ForegroundColor Cyan
try {
    Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, LinkSpeed |
        Format-Table -AutoSize
    Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway |
        Format-List
} catch { Write-Warning "Consulta de rede indisponivel: $($_.Exception.Message)" }

Write-Host "=== 5. SERVICOS IMPORTANTES ===" -ForegroundColor Cyan
$names = 'WinRM', 'W32Time', 'Netlogon', 'DNS', 'NTDS', 'vmms', 'ClusSvc', 'wuauserv'
Get-Service -Name $names -ErrorAction SilentlyContinue |
    Select-Object Name, Status, StartType |
    Format-Table -AutoSize

Write-Host "=== 6. FUNCOES INSTALADAS (APENAS WINDOWS SERVER) ===" -ForegroundColor Cyan
if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
    Get-WindowsFeature | Where-Object Installed |
        Select-Object Name, DisplayName |
        Format-Table -AutoSize
} else {
    Write-Host "Get-WindowsFeature nao esta disponivel neste host."
}

Write-Host "=== 7. HYPER-V (SE INSTALADO E AUTORIZADO) ===" -ForegroundColor Cyan
if (Get-Command Get-VM -ErrorAction SilentlyContinue) {
    try {
        Get-VM -ErrorAction Stop |
            Select-Object Name, State, ProcessorCount, MemoryAssigned, Uptime |
            Format-Table -AutoSize
    } catch {
        Write-Warning "Hyper-V instalado, mas nao foi possivel consultar VMs: $($_.Exception.Message)"
    }
} else {
    Write-Host "Modulo Hyper-V nao presente neste host."
}

Write-Host "=== FIM: COLETA READ-ONLY ===" -ForegroundColor Green
Write-Host "Evite publicar nomes de hosts, IPs, dominio e inventario corporativo em repositorios publicos."
