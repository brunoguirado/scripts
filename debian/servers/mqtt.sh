#!/usr/bin/env bash

# MQTT Mosquitto Broker Installation & Management Script
# Role: Senior DevSecOps Engineer
# Features: Hardening, User Management, Persistence

set -euo pipefail

# --- Configuration ---
LOG_FILE="/var/log/mqtt-install.log"
PASSWD_FILE="/etc/mosquitto/passwd"
CONFIG_FILE="/etc/mosquitto/conf.d/default.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Helper Functions ---

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2; exit 1; }

check_root() {
    [[ $EUID -ne 0 ]] && error "This script must be run as root."
}

# --- MQTT Management ---

list_users() {
    if [[ ! -f "$PASSWD_FILE" ]]; then
        echo -e "${YELLOW}Arquivo de senhas não encontrado.${NC}"
        return
    fi
    echo -e "${BLUE}Usuários MQTT cadastrados:${NC}"
    # Extract only the username part before the colon
    cut -d: -f1 "$PASSWD_FILE"
}

manage_user() {
    read -p "Nome do usuário MQTT: " USERNAME
    if [[ -f "$PASSWD_FILE" ]]; then
        # If file exists, use -b to avoid prompt or just run normally
        mosquitto_passwd "$PASSWD_FILE" "$USERNAME"
    else
        # If file doesn't exist, use -c to create it
        mosquitto_passwd -c "$PASSWD_FILE" "$USERNAME"
    fi
    systemctl restart mosquitto
    success "Usuário $USERNAME criado/atualizado. Broker reiniciado."
}

delete_user() {
    read -p "Nome do usuário MQTT a excluir: " USERNAME
    if [[ ! -f "$PASSWD_FILE" ]]; then
        error "Arquivo de senhas não existe."
    fi
    mosquitto_passwd -D "$PASSWD_FILE" "$USERNAME"
    systemctl restart mosquitto
    success "Usuário $USERNAME removido. Broker reiniciado."
}

user_menu() {
    while true; do
        echo -e "\n${YELLOW}=== Gestão de Usuários MQTT (Mosquitto) ===${NC}"
        echo "1) Listar Usuários"
        echo "2) Criar / Alterar Senha de Usuário"
        echo "3) Excluir Usuário"
        echo "4) Voltar / Sair"
        read -p "Escolha uma opção: " OPT
        case $OPT in
            1) list_users ;;
            2) manage_user ;;
            3) delete_user ;;
            4) return 0 ;;
            *) echo "Opção inválida." ;;
        esac
    done
}

# --- Installation Logic ---

install_mqtt() {
    log "Updating system and installing Mosquitto..."
    apt-get update && apt-get upgrade -y | tee -a "$LOG_FILE"
    apt-get install -y mosquitto mosquitto-clients | tee -a "$LOG_FILE" || error "Failed to install Mosquitto."

    log "Configuring Security Hardening..."
    # Clean and create new config
    cat <<EOF > "$CONFIG_FILE"
# --- Senior DevSecOps Hardening ---
listener 1883
allow_anonymous false
password_file ${PASSWD_FILE}
EOF

    log "Setting up initial admin user..."
    read -p "Digite o nome do usuário admin inicial: " ADMIN_USER
    mosquitto_passwd -c "$PASSWD_FILE" "$ADMIN_USER"

    log "Enabling and starting Mosquitto..."
    systemctl enable mosquitto
    systemctl restart mosquitto || error "Failed to start Mosquitto."

    success "Mosquitto MQTT Broker instalado e configurado na porta 1883."
}

# --- Main ---

main() {
    check_root
    
    if command -v mosquitto &>/dev/null; then
        echo -e "${GREEN}Broker MQTT (Mosquitto) detectado!${NC}"
        user_menu
    else
        echo -e "${YELLOW}MQTT não encontrado. Iniciando instalação conforme mqtt-broker.md...${NC}"
        install_mqtt
        echo -e "${BLUE}Deseja realizar mais gestão de usuários?${NC}"
        user_menu
    fi
}

main "$@"
