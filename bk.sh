#!/bin/bash

# Definindo cores para saída visual
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # Sem cor

# Arquivo de configuração
CONFIG_FILE="backup_restore_config.conf"

# Função para exibir o progresso (bar simples)
progresso() {
    local progress=$1
    local total=$2
    local percent=$((progress * 100 / total))
    local filled=$(printf "%${percent}s" "#" | tr " " "#")
    local empty=$(printf "%$((100 - percent))s" " " | tr " " "#")
    echo -e "${CYAN}[${filled}${empty}] ${percent}%${NC}"
}

# Função para carregar configurações
carregar_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Configurações padrão
        DB_HOST="localhost"
        DB_PORT="5432"
        DB_USER="postgres"
        DB_NAME="exemplo"
        BACKUP_DIR="/home/Backup"
        FOLDER_NAME="/home/deploy/exemplo"
        BACKUP_TIME="18:00"
        PGPASSWORD="exemplo" # Senha agora configurável

        salvar_config
    fi
}

# Função para salvar configurações
salvar_config() {
    cat > "$CONFIG_FILE" <<EOL
DB_HOST="$DB_HOST"
DB_PORT="$DB_PORT"
DB_USER="$DB_USER"
DB_NAME="$DB_NAME"
BACKUP_DIR="$BACKUP_DIR"
FOLDER_NAME="$FOLDER_NAME"
BACKUP_TIME="$BACKUP_TIME"
PGPASSWORD="$PGPASSWORD"
EOL
}

# Função para exibir configurações atuais
exibir_config() {
    echo -e "${GREEN}Configurações atuais:${NC}"
    echo -e "Host do Banco de Dados: ${YELLOW}$DB_HOST${NC}"
    echo -e "Porta do Banco de Dados: ${YELLOW}$DB_PORT${NC}"
    echo -e "Usuário do Banco de Dados: ${YELLOW}$DB_USER${NC}"
    echo -e "Nome do Banco de Dados: ${YELLOW}$DB_NAME${NC}"
    echo -e "Diretório de Backups: ${YELLOW}$BACKUP_DIR${NC}"
    echo -e "Pasta para Backup: ${YELLOW}$FOLDER_NAME${NC}"
    echo -e "Horário de Backup Automático: ${YELLOW}$BACKUP_TIME${NC}"
    echo -e "Senha PGPASSWORD: ${YELLOW}$PGPASSWORD${NC}"
}

# Função para alterar configurações
alterar_config() {
    echo -e "${MAGENTA}Vamos dar uma ajeitada nas configurações! 💻⚙️${NC}"
    read -p "Host do Banco de Dados [$DB_HOST]: " new_host
    DB_HOST=${new_host:-$DB_HOST}

    read -p "Porta do Banco de Dados [$DB_PORT]: " new_port
    DB_PORT=${new_port:-$DB_PORT}

    read -p "Usuário do Banco de Dados [$DB_USER]: " new_user
    DB_USER=${new_user:-$DB_USER}

    read -p "Nome do Banco de Dados [$DB_NAME]: " new_name
    DB_NAME=${new_name:-$DB_NAME}

    read -p "Diretório de Backups [$BACKUP_DIR]: " new_backup_dir
    BACKUP_DIR=${new_backup_dir:-$BACKUP_DIR}

    echo -e "${YELLOW}Escolha uma pasta para backup:${NC}"
    PS3="Escolha a pasta para backup: "
    select folder in $(ls /home/deploy); do
        if [ -n "$folder" ]; then
            FOLDER_NAME="/home/deploy/$folder"
            break
        else
            echo -e "${RED}Opção inválida.${NC}"
        fi
    done

    read -p "Horário de Backup Automático (HH:MM) [$BACKUP_TIME]: " new_time
    BACKUP_TIME=${new_time:-$BACKUP_TIME}

    read -p "Senha PGPASSWORD [$PGPASSWORD]: " new_password
    PGPASSWORD=${new_password:-$PGPASSWORD}

    salvar_config
    configurar_cron
    echo -e "${GREEN}Configurações atualizadas com sucesso! 🎉${NC}"
}

# Função para configurar o cron para backup automático
configurar_cron() {
    CRON_HOUR=$(echo $BACKUP_TIME | cut -d':' -f1)
    CRON_MIN=$(echo $BACKUP_TIME | cut -d':' -f2)

    crontab -l | grep -v "$(realpath $0)" | crontab -

    (crontab -l 2>/dev/null; echo "$CRON_MIN $CRON_HOUR * * * $(realpath $0) --backup") | crontab -
    echo -e "${GREEN}Backup automático configurado para $BACKUP_TIME diariamente. ⏰${NC}"
}

# Função para verificar e instalar o zip se necessário
verificar_zip() {
    if ! command -v zip &> /dev/null; then
        echo -e "${YELLOW}Zip não encontrado. Instalando... 🚀${NC}"
        sudo apt install -y zip
    fi
}

# Função para criar backup
fazer_backup() {
    echo -e "${YELLOW}Iniciando o backup... 🛠️${NC}"

    # Verificar se o zip está instalado
    verificar_zip

    if [ ! -d "$BACKUP_DIR" ]; then
        echo -e "${YELLOW}Criando diretório de backups: $BACKUP_DIR 📂${NC}"
        mkdir -p "$BACKUP_DIR"
    fi

    BACKUP_FILE="$BACKUP_DIR/${DB_NAME}-$(date +%Y%m%d%H%M%S).sql"
    echo -e "${YELLOW}Fazendo backup do banco de dados $DB_NAME... 💾${NC}"
    PGPASSWORD=$PGPASSWORD pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER $DB_NAME > $BACKUP_FILE

    progresso 1 5

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup do banco de dados salvo em: $BACKUP_FILE ✅${NC}"
    else
        echo -e "${RED}Erro ao realizar o backup do banco de dados. ❌${NC}"
        exit 1
    fi

    ZIP_FILE="$BACKUP_DIR/-$(date +%Y%m%d%H%M%S).zip"
    echo -e "${YELLOW}Fazendo backup da pasta $FOLDER_NAME... 📦${NC}"
    zip -r $ZIP_FILE $FOLDER_NAME -x "*node_modules/*" "*build/*" "*dist/*" "*public/*"

    progresso 3 5

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Backup da pasta salvo em: $ZIP_FILE ✅${NC}"
    else
        echo -e "${RED}Erro ao realizar o backup da pasta. ❌${NC}"
        exit 1
    fi
}

# Função para restaurar backup
restaurar_backup() {
    echo -e "${YELLOW}Listando backups disponíveis... 📑${NC}"
    ls -l $BACKUP_DIR/*.sql

    read -p "Digite o caminho completo do arquivo de backup do banco de dados (.sql): " BACKUP_FILE
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}Arquivo $BACKUP_FILE não encontrado. 😱${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Finalizando conexões no banco de dados $DB_NAME... 🛑${NC}"
    PGPASSWORD=$PGPASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$DB_NAME' AND pid <> pg_backend_pid();" &> /dev/null

    echo -e "${YELLOW}Droppando o banco de dados $DB_NAME... 🧨${NC}"
    PGPASSWORD=$PGPASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;" &> /dev/null

    echo -e "${YELLOW}Recriando o banco de dados $DB_NAME... 🔄${NC}"
    PGPASSWORD=$PGPASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d postgres -c "CREATE DATABASE $DB_NAME;" &> /dev/null

    echo -e "${YELLOW}Restaurando o backup no banco de dados $DB_NAME... 🔄${NC}"
    PGPASSWORD=$PGPASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Banco de dados restaurado com sucesso! 🎉${NC}"
    else
        echo -e "${RED}Erro ao restaurar o banco de dados. 😓${NC}"
        exit 1
    fi
}

# Menu principal
carregar_config
if [ "$1" == "--backup" ]; then
    fazer_backup
    exit 0
fi

while true; do
    echo -e "${GREEN}Escolha uma opção:${NC}"
    echo "1) Fazer backup"
    echo "2) Restaurar backup"
    echo "3) Configurar sistema"
    echo "4) Exibir configurações atuais"
    echo "5) Sair"
    read -p "Opção: " OPTION

    case $OPTION in
        1)
            fazer_backup
            ;;
        2)
            restaurar_backup
            ;;
        3)
            alterar_config
            ;;
        4)
            exibir_config
            ;;
        5)
            echo -e "${GREEN}Saindo... 😎${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opção inválida. Tente novamente. 🤔${NC}"
            ;;
    esac
done
