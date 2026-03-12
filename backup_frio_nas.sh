#!/bin/bash

# Trava de segurança rigorosa
set -euo pipefail

PROJECT_DIR="/home/canela/git/Nuvem-Privada"
BACKUP_DEST="/mnt/Arquive/Backup-NAS"
DATA_HORA=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DEST/backup_nuvem_${DATA_HORA}.tar.xz"

echo "====================================================="
echo " Iniciando Rotina de Cold Backup de Alta Compressão"
echo "====================================================="

mkdir -p "$BACKUP_DEST"
cd "$PROJECT_DIR"

echo "[1/4] Desligando os motores para garantir consistência do MariaDB..."
docker-compose down

echo "[2/4] Calculando o volume de dados bruto..."
# Conta exatamente quantos bytes existem na pasta para o 'pv' saber o 100%
TAMANHO_TOTAL=$(du -sb . | awk '{print $1}')

echo "[3/4] Compactando a infraestrutura (Compressão Extrema Multicore)..."
# A Engenharia do Pipeline:
# 1. tar empacota tudo e manda pro tubo (stdout)
# 2. pv lê o tubo, desenha a barra na tela e passa pra frente
# 3. xz pega o tubo, usa nível 9 de qualidade (-9) e todas as threads do processador (-T0)
tar -cf - . | pv -s "$TAMANHO_TOTAL" | xz -z -9 -T0 --memlimit=7GiB > "$BACKUP_FILE"

echo ""
echo "[4/4] Religa o servidor para não interromper o uso..."
docker-compose up -d

echo "====================================================="
echo " Backup concluído com excelência!"
echo " Arquivo gerado: $BACKUP_FILE"
echo " Tamanho final: $(du -h "$BACKUP_FILE" | awk '{print $1}')"
echo "====================================================="
