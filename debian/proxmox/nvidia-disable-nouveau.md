# Disable Driver Nouveau (Proxmox VE)
Este guia documenta o procedimento para desativar o driver Nouveau e permitir o funcionamento correto dos drivers proprietários NVIDIA em ambientes Proxmox.

🛠️ Pré-requisitos
Acesso root ao Shell do Proxmox.

Verificação de hardware via CLI: 09:00.0 VGA compatible controller: NVIDIA Corporation GP108 [GeForce GT 1030] (rev a1).

1. Criação da Blacklist
O Kernel Linux carrega o Nouveau por padrão. Devemos impedi-lo criando um arquivo de configuração em /etc/modprobe.d/.

```bash
nano /etc/modprobe.d/blacklist-nouveau.conf
```

Conteúdo do arquivo:

```text
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
```

2. Atualização do Initramfs
Para que a alteração seja gravada na imagem de inicialização do sistema (RAM Disk), execute:

```bash
update-initramfs -u
```
Nota: Se você utiliza o systemd-boot (ZFS), certifique-se de que as alterações foram propagadas para a partição EFI.

3. Persistência e Reinicialização
Após o reboot, valide se o driver foi removido da memória:

```bash
lsmod | grep nouveau
```
Se o comando não retornar nada, o Nouveau foi desativado com sucesso.

4. Validação do Driver NVIDIA
Com o Nouveau fora do caminho, o comando nvidia-smi deve agora comunicar-se com a GPU:

```bash
nvidia-smi
```
