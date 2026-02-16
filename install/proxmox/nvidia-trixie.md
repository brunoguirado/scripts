Aqui está o guia técnico detalhado no formato Markdown que documenta a solução "Senior Expert" aplicada para estabilizar o seu ambiente experimental.

---

# Guia de Instalação: NVIDIA GT 1030 no Proxmox 9 (Trixie/Kernel 6.17)

Este documento descreve o procedimento passo a passo para instalar drivers NVIDIA em um ambiente **Debian 13 (Trixie)** com **Kernel 6.17**, superando as incompatibilidades de API que impedem a instalação via repositórios padrão.

## 1. Diagnóstico de Conflito

* **Problema Identificado**: O Kernel 6.17 alterou a assinatura da função `fb_create` na API DRM, causando falha de compilação nos drivers NVIDIA estáveis (535/550).
* **Impacto**: Erros fatais durante o `dkms build` e risco de remoção do pacote `proxmox-ve` ao tentar resolver dependências via `apt`.

## 2. Passo a Passo da Solução

### Passo 1: Limpeza do Ambiente

Antes de iniciar a instalação limpa, é necessário remover qualquer vestígio de instalações que falharam para destravar o `dpkg`.

```bash
apt purge nvidia-* -y
apt autoremove -y
apt clean

```

### Passo 2: Preparação do Host

Instalamos as ferramentas de compilação e os cabeçalhos específicos do Kernel Proxmox 6.17.

```bash
apt update
apt install -y pve-headers-$(uname -r) build-essential dkms pkg-config libglvnd-dev

```

### Passo 3: Instalação Manual do Driver 580.126.09

Optamos pelo driver **580.126.09**, que já contém os patches necessários para os Kernels mais recentes.

1. **Download do Instalador**:
```bash
wget https://us.download.nvidia.com/XFree86/Linux-x86_64/580.126.09/NVIDIA-Linux-x86_64-580.126.09.run
chmod +x NVIDIA-Linux-x86_64-580.126.09.run

```


2. **Execução**:
```bash
./NVIDIA-Linux-x86_64-580.126.09.run --dkms

```


* *Nota: Selecionar "Yes" para o registro no DKMS para garantir persistência em atualizações de kernel.*



### Passo 4: Validação no Host

Verificamos se o driver está carregado e se comunicando com a **GT 1030**.

```bash
nvidia-smi

```

* **Resultado Esperado**: Tabela exibindo a GPU, temperatura operacional (ex: 37°C) e a versão do driver 580.126.09.

---

## 3. Configuração de Passthrough para LXC (Frigate/NVR)

Para que o container acesse a placa, realizamos o mapeamento de hardware no arquivo de configuração do Proxmox.

### Edição do Arquivo `.conf`

No Host, edite `/etc/pve/lxc/ID_DO_CONTAINER.conf` e adicione:

```conf
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 234:* rwm
lxc.cgroup2.devices.allow: c 237:* rwm
lxc.cgroup2.devices.allow: c 243:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file

```

### Instalação no Container

Dentro do LXC, instalamos apenas as bibliotecas de usuário com o mesmo instalador:

```bash
./NVIDIA-Linux-x86_64-580.126.09.run --no-kernel-module --no-questions --ui=none
```

O "Ponte" para a GPU (NVIDIA Container Toolkit)
```bash
# Adiciona o repositório do NVIDIA Container Toolkit
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb [^ ]* \(.*\)#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://nvidia.github.io/libnvidia-container/stable/deb/\1#' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Instala o Toolkit
apt update
apt install -y nvidia-container-toolkit
```

---

## 4. Veredito Técnico

A utilização do instalador oficial com suporte a **DKMS** em vez dos pacotes do repositório Trixie garantiu a estabilidade do sistema, evitando a remoção acidental de componentes vitais do Proxmox e permitindo a aceleração total via **CUDA 13.0**.

---

**Deseja que eu te ajude agora a configurar os parâmetros de detecção TensorRT no seu arquivo `config.yml` do Frigate para aproveitar os 2GB da sua placa?**
