#!/bin/bash

#================================================
# VARIAVEIS - PREENCHA ANTES DE EXECUTAR
#================================================
VPN_NAME=""          # ex: vpn-escritorio, vpn-cliente1
VPN_SERVER_IP=""
VPN_IPSEC_PSK=""
VPN_USER=""
VPN_PASSWORD=""
VPN_REMOTE_NET=""    # ex: 192.168.1.0/24
#================================================

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validar variaveis
if [[ -z "$VPN_NAME" || -z "$VPN_SERVER_IP" || -z "$VPN_IPSEC_PSK" || -z "$VPN_USER" || -z "$VPN_PASSWORD" || -z "$VPN_REMOTE_NET" ]]; then
  echo -e "${RED}ERRO: Preencha todas as variáveis antes de executar!${NC}"
  exit 1
fi

# Identificar interfaces automaticamente
echo -e "${YELLOW}Identificando interfaces de rede...${NC}"

# Interface WAN = que tem a rota default
IFACE_WAN=$(ip route show default | awk '/default/ {print $5}' | head -n1)

# Interface LAN = segunda interface (não WAN, não loopback, não ppp)
IFACE_LAN=$(ip link show | awk -F': ' '{print $2}' | grep -v lo | grep -v ppp | grep -E '^ens|^eth|^enp' | grep -v "$IFACE_WAN" | head -n1)

# Validar se encontrou as interfaces
if [[ -z "$IFACE_WAN" ]]; then
  echo -e "${RED}ERRO: Não foi possível identificar a interface WAN!${NC}"
  exit 1
fi

if [[ -z "$IFACE_LAN" ]]; then
  echo -e "${RED}ERRO: Não foi possível identificar a interface LAN!${NC}"
  echo -e "${YELLOW}Interfaces disponíveis:${NC}"
  ip link show | awk -F': ' '{print $2}' | grep -E '^ens|^eth|^enp'
  exit 1
fi

echo -e "${BLUE}Interface WAN (acesso VPN) : ${IFACE_WAN}${NC}"
echo -e "${BLUE}Interface LAN (clientes)   : ${IFACE_LAN}${NC}"

# Confirmar antes de continuar
read -p "As interfaces estão corretas? (s/n): " CONFIRM
if [[ "$CONFIRM" != "s" ]]; then
  echo -e "${YELLOW}Edite manualmente as variáveis IFACE_WAN e IFACE_LAN no script.${NC}"
  exit 1
fi

# Validar se nome já existe
if nmcli connection show "$VPN_NAME" > /dev/null 2>&1; then
  echo -e "${RED}ERRO: Já existe uma conexão com o nome '${VPN_NAME}'!${NC}"
  echo -e "${YELLOW}Use outro nome em VPN_NAME ou remova com:${NC}"
  echo -e "nmcli connection delete '${VPN_NAME}'"
  exit 1
fi

echo -e "${YELLOW}Instalando dependências...${NC}"
apt update && apt upgrade -y
apt install -y network-manager network-manager-l2tp iptables-persistent net-tools

echo -e "${YELLOW}Habilitando NetworkManager...${NC}"
systemctl enable NetworkManager
systemctl start NetworkManager

echo -e "${YELLOW}Criando conexão VPN...${NC}"
nmcli connection add \
  type vpn \
  vpn-type l2tp \
  con-name "${VPN_NAME}" \
  ifname "*" 2>/dev/null

echo -e "${YELLOW}Gerando arquivo de configuração VPN...${NC}"
cat > /etc/NetworkManager/system-connections/${VPN_NAME}.nmconnection << EOF
[connection]
id=${VPN_NAME}
type=vpn
autoconnect=yes

[vpn]
gateway=${VPN_SERVER_IP}
user=${VPN_USER}
password-flags=0
ipsec-enabled=yes
ipsec-psk=${VPN_IPSEC_PSK}
service-type=org.freedesktop.NetworkManager.l2tp

[vpn-secrets]
password=${VPN_PASSWORD}
ipsec-psk=${VPN_IPSEC_PSK}

[ipv4]
method=auto
EOF

echo -e "${YELLOW}Ajustando permissões...${NC}"
chmod 600 /etc/NetworkManager/system-connections/${VPN_NAME}.nmconnection

echo -e "${YELLOW}Recarregando conexões...${NC}"
nmcli connection reload

echo -e "${YELLOW}Conectando VPN...${NC}"
nmcli connection up "${VPN_NAME}"

# Verificar se conectou
if ip addr show ppp0 > /dev/null 2>&1; then
  echo -e "${GREEN}VPN conectada com sucesso!${NC}"
else
  echo -e "${RED}ERRO: VPN não conectou, verifique as credenciais!${NC}"
  exit 1
fi

echo -e "${YELLOW}Configurando Gateway...${NC}"

# IP Forward
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# NAT e Forward com interfaces identificadas
iptables -t nat -A POSTROUTING -o ppp0 -j MASQUERADE
iptables -A FORWARD -i ${IFACE_LAN} -o ppp0 -j ACCEPT
iptables -A FORWARD -i ppp0 -o ${IFACE_LAN} -m state --state RELATED,ESTABLISHED -j ACCEPT

# Salvar regras
netfilter-persistent save

# Rota para rede remota
ip route add ${VPN_REMOTE_NET} dev ppp0 2>/dev/null

# Rota permanente
cat > /etc/network/interfaces.d/${VPN_NAME}-route << EOF
up ip route add ${VPN_REMOTE_NET} dev ppp0
EOF

echo -e "${GREEN}"
echo "================================================"
echo " VPN Gateway configurado com sucesso!"
echo "================================================"
echo " Nome VPN    : ${VPN_NAME}"
echo " Interface WAN : ${IFACE_WAN}"
echo " Interface LAN : ${IFACE_LAN}"
echo " IP VPN      : $(ip addr show ppp0 | grep 'inet ' | awk '{print $2}')"
echo " IP Local    : $(ip addr show ${IFACE_LAN} | grep 'inet ' | awk '{print $2}')"
echo " Rede VPN    : ${VPN_REMOTE_NET}"
echo "================================================"
echo " Aponte o gateway dos clientes para:"
echo " $(ip addr show ${IFACE_LAN} | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"
echo "================================================"
echo -e "${NC}"
