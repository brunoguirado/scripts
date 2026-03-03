# Instalação do Home Assistant OS no Proxmox

## Passo a Passo Visual

### 1. Configuração Inicial da VM (Aba Geral)


```bash
qm create 900 --name haos --net0 virtio,bridge=vmbr0 --machine q35 --ostype l26 --cpu host --cores 2 --memory 2048 --agent 1 --bios ovmf --efidisk0 local-lvm:0,format=raw,pre-enrolled-keys=0 --scsihw virtio-scsi-pci
```

## Instruções de Linha de Comando no Console

### 1. Baixar a Imagem do Home Assistant OS

```bash
wget -P /tmp https://github.com/home-assistant/operating-system/releases/download/17.0/haos_ova-17.0.qcow2.xz
```

### 2. Descompactar a Imagem

```bash
unxz /tmp/haos_ova-17.0.qcow2.xz
```

> **Nota:** Este processo pode levar alguns segundos.

### 3. Importar o Disco para a VM 900

```bash
qm importdisk 900 /tmp/haos_ova-17.0.qcow2 local-lvm
```



## Configuração Pós-Importação

No Web Console do Proxmox, Adicionar o disco importado com VirtIO SCSI

Cache Write Back
IO threads: Checked
Emulação SSD: Checked

Backup: Unchecked

## Em Options

Boot Order: HDD em primeiro

---