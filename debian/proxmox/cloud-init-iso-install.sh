#!/usr/bin/env bash

# Encerrar o script em caso de erro
set -e

echo "Verificando permissões de root..."
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script como root (ou use sudo)."
  exit 1
fi

echo "1. Atualizando pacotes e instalando dependências essenciais..."
apt-get update
# Adicionado openssh-server para garantir o acesso SSH pós-cloud-init
apt-get install -y cloud-init qemu-guest-agent cloud-guest-utils openssh-server

echo "2. Configurando a Fonte de Dados (Datasource) para Proxmox..."
# Garantir que o diretório existe
mkdir -p /etc/cloud/cloud.cfg.d/

# Adicionando explicitamente NoCloud e ConfigDrive (padrão do Proxmox)
cat <<EOF > /etc/cloud/cloud.cfg.d/99_installer.cfg
datasource_list: [ NoCloud, ConfigDrive ]
EOF

echo "3. Habilitando os serviços do cloud-init no boot..."
systemctl enable cloud-init-local.service
systemctl enable cloud-init.service
systemctl enable cloud-config.service
systemctl enable cloud-final.service

echo "4. Limpando o estado do cloud-init para o 'Primeiro Boot'..."
cloud-init clean --logs --seed

echo "4.5 [Extra] Preparando a Rede (Limpando interfaces antigas)..."
# O Debian configura a rede no /etc/network/interfaces durante a instalação.
# Isso impede o cloud-init de aplicar o IP na VM clonada. Vamos deixar apenas o loopback.
cat <<EOF > /etc/network/interfaces
# The loopback network interface
auto lo
iface lo inet loopback
EOF
rm -f /etc/udev/rules.d/70-persistent-net.rules

echo "5. [Extra] Limpando o machine-id (Essencial para templates no Proxmox)..."
# É importante limpar o machine-id. Se você clonar a VM, sem limpar isso,
# todas as VMs clonadas pegarão o mesmo endereço IP via DHCP.
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    rm -f /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

echo "6. [Extra] Limpando cache do APT para reduzir o tamanho da imagem..."
apt-get clean
rm -rf /var/lib/apt/lists/*
rm -rf /var/log/*

echo "======================================================================"
echo "Pronto! O sistema está preparado para rodar o cloud-init no próximo boot."
echo "======================================================================"
