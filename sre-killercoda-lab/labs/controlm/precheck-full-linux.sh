#!/usr/bin/env bash
# Control-M FULL INSTALLATION 9.0.27 — pré-verificação read-only (sem BMC).
# Não altera SO, usuários, firewall, banco, VM, serviços ou arquivos.
# Requer Bash, /proc e utilitários Linux comuns. Execute SOMENTE em VM destinada ao laboratório.
set -uo pipefail

echo "=== PRE-CHECK FULL CONTROLM 9.0.27 (SOMENTE LEITURA) ==="
echo "OBS: este script NÃO substitui o CheckReq oficial e NÃO instala Control-M."
echo
os=$(awk -F= '/^PRETTY_NAME=/{print $2;exit}' /etc/os-release 2>/dev/null | tr -d '"')
arch=$(uname -m 2>/dev/null || echo desconhecida)
cpu=$(nproc 2>/dev/null || echo 0)
ram_mib=$(awk '/^MemTotal:/{print int($2/1024)}' /proc/meminfo 2>/dev/null)
[ -n "$ram_mib" ] || ram_mib=0
fqdn=$(hostname -f 2>/dev/null || hostname)
disk_kib=$(df -Pk /opt 2>/dev/null | awk 'NR==2 {print $4}')
[ -n "$disk_kib" ] || disk_kib=0
disk_gib=$((disk_kib / 1024 / 1024))

echo "SO: $os"
echo "Hostname: $fqdn"
echo "CPU arch: $arch"
echo "vCPU: $cpu"
echo "RAM fisica aproximada: $ram_mib MiB"
echo "Disco livre no filesystem de /opt: $disk_gib GiB"
echo

warnings=0
if [[ $arch == x86_64 ]]; then echo "[OK] CPU x86_64"; else echo "[ALERTA] CPU diferente de x86_64"; warnings=$((warnings+1)); fi
if [[ $cpu =~ ^[0-9]+$ ]] && (( cpu >= 4 )); then echo "[OK] pelo menos 4 vCPUs"; else echo "[ALERTA] menos de 4 vCPUs"; warnings=$((warnings+1)); fi
if (( ram_mib >= 24576 )); then echo "[OK] pelo menos 24GiB de RAM de projeto"; else echo "[ALERTA] menos de 24GiB de RAM para Full com PostgreSQL local"; warnings=$((warnings+1)); fi
if (( disk_gib >= 100 )); then echo "[OK] pelo menos 100GiB livres em /opt"; else echo "[ALERTA] menos de 100GiB livres em /opt (verifique volume de instalacao escolhido)"; warnings=$((warnings+1)); fi

echo
echo "=== CONTEXTO ADICIONAL ==="
command -v free >/dev/null 2>&1 && free -h || :
command -v swapon >/dev/null 2>&1 && swapon --show || :
command -v timedatectl >/dev/null 2>&1 && timedatectl 2>&1 | head -15 || :
command -v java >/dev/null 2>&1 && java -version 2>&1 || echo "[PENDENTE] Java externo nao identificado"
command -v tcsh >/dev/null 2>&1 && echo "[OK] tcsh presente" || echo "[PENDENTE] instalar tcsh, se SO homologado"
command -v ss >/dev/null 2>&1 && ss -lnt 2>&1 | head -25 || :
echo
echo "=== PENDENCIAS MANUAIS ==="
echo "Valide: contrato/trial BMC, media EPD legitima, Release Notes e matriz SO/Java,"
echo "certificados TLS, hostname/DNS, NTP, politicas PAM/ulimit, swap, firewall"
echo "e o CheckReq OFICIAL do pacote com: -product=ONE -memory_model=SMALL -database=PostgreSQL"
echo
echo "Alertas basicos: $warnings"
echo "Resultado: somente inventario. Nao declarar prontidao de instalacao sem CheckReq."
