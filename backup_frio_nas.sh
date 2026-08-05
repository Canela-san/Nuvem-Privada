#!/bin/bash

# Trava de segurança rigorosa
set -euo pipefail

PROJECT_DIR="/home/canela/git/Nuvem-Privada"
BACKUP_DEST="/mnt/Arquive/Backup-NAS"
DATA_HORA=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="$BACKUP_DEST/backup_nuvem_${DATA_HORA}.tar.xz"

# Quantos dias de backups antigos manter antes de apagar automaticamente
RETENCAO_DIAS=30

echo "====================================================="
echo " Iniciando Rotina de Cold Backup de Alta Compressão"
echo "====================================================="

mkdir -p "$BACKUP_DEST"
cd "$PROJECT_DIR"

echo "[1/6] Gerando dump lógico do banco de dados (com os motores ainda ligados)..."
# Um dump lógico (SQL) complementa o backup físico do volume: é mais portável entre
# versões do MariaDB e permite restaurar/inspecionar o banco isoladamente, sem
# precisar recuperar o volume inteiro.
mkdir -p "$PROJECT_DIR/db_dump"
docker compose exec -T db sh -c 'exec mariadb-dump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases' \
    | gzip > "$PROJECT_DIR/db_dump/dump_latest.sql.gz"

echo "[2/6] Desligando os motores para garantir consistência do MariaDB..."
docker compose down

echo "[3/6] Calculando o volume de dados bruto..."
# Conta exatamente quantos bytes existem na pasta para o 'pv' saber o 100%
TAMANHO_TOTAL=$(du -sb . | awk '{print $1}')

echo "[4/6] Compactando a infraestrutura (Compressão Extrema Multicore)..."
# A Engenharia do Pipeline:
# 1. tar empacota tudo e manda pro tubo (stdout) - incluindo o dump lógico gerado acima
# 2. pv lê o tubo, desenha a barra na tela e passa pra frente
# 3. xz pega o tubo, usa nível 9 de qualidade (-9) e todas as threads do processador (-T0)
tar -cf - . | pv -s "$TAMANHO_TOTAL" | xz -z -9 -T0 --memlimit=7GiB > "$BACKUP_FILE"

echo "[5/6] Verificando integridade do arquivo compactado..."
if ! xz -t "$BACKUP_FILE"; then
    echo "ERRO: o arquivo de backup está corrompido! Religando os motores e abortando." >&2
    docker compose up -d
    exit 1
fi
echo "-> Integridade confirmada."

echo "[6/6] Religa o servidor e limpa backups antigos (retenção de $RETENCAO_DIAS dias)..."
docker compose up -d
find "$BACKUP_DEST" -maxdepth 1 -name "backup_nuvem_*.tar.xz" -mtime "+$RETENCAO_DIAS" -print -delete

echo "====================================================="
echo " Backup concluído com excelência!"
echo " Arquivo gerado: $BACKUP_FILE"
echo " Tamanho final: $(du -h "$BACKUP_FILE" | awk '{print $1}')"
echo "====================================================="