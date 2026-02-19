### 1. Preparação da Estrutura de Pastas

Para manter o servidor organizado e facilitar backups futuros:

1. No terminal do seu **LXC**, crie o diretório base:
```bash
mkdir -p /opt/frigate/config /opt/frigate/storage
cd /opt/frigate

```



### 2. Criação do arquivo `docker-compose.yml`

Este arquivo orquestra o container e garante que o Docker saiba que deve reservar a GPU para o Frigate.

1. Crie o arquivo: `nano docker-compose.yml`
2. Cole o conteúdo abaixo:

```yaml
services:
  frigate:
    container_name: frigate
    privileged: true # Necessário para acesso direto ao hardware no LXC
    restart: unless-stopped
    image: ghcr.io/blakeblackshear/frigate:stable
    shm_size: "2gb" # Ajuste conforme o número de câmeras, reservar entre 64MB a 128MB por câmera para evitar gargalos.
    devices:
      - /dev/nvidia0:/dev/nvidia0
      - /dev/nvidiactl:/dev/nvidiactl
      - /dev/nvidia-uvm:/dev/nvidia-uvm
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./config:/config
      - ./storage:/media/frigate
      - type: tmpfs # Protege seu SSD do desgaste de escrita constante
        target: /tmp/cache
        tmpfs:
          size: 1000000000 # 1GB de cache na RAM
    ports:
      - "8971:8971"
      - "5000:5000" # Interface Web
    environment:
      - FRIGATE_RTSP_PASSWORD=sua_senha_forte
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

```

### 3. Configuração Inicial do Frigate (`config.yml`)

Este é o arquivo onde ativamos o **TensorRT** (IA na GPU) e o **NVDEC** (Decodificação na GPU).

1. Crie o arquivo na pasta de config: `nano config/config.yml`
2. Cole esta configuração base:

```yaml
mqtt:
  enabled: False # Ative depois para integrar com o Home Assistant

detectors:
  tensorrt:
    type: tensorrt
    device: 0 # Sua GT 1030

ffmpeg:
  hwaccel_args: preset-nvidia-h264 # Força o uso do NVDEC

cameras:
  camera_teste: # Mude para o nome da sua câmera
    enabled: True
    ffmpeg:
      inputs:
        - path: rtsp://usuario:senha@ip_da_camera:554/stream
          roles:
            - detect
            - record
    detect:
      enabled: True
      width: 1280 # Use a resolução do seu sub-stream
      height: 720
      fps: 5

```

---

### 4. Inicialização e Teste

Agora vamos subir o serviço e monitorar o comportamento do hardware.

1. Suba o container:
```bash
docker compose up -d

```


2. Acompanhe o processamento na GPU:
```bash
watch -n 1 nvidia-smi

```



### Comparativo de Eficiência (Frigate + GT 1030)

| Recurso | Sem Aceleração (CPU) | Com TensorRT + NVDEC |
| --- | --- | --- |
| **Carga no CPU** | Alta (Pode travar o Host) | **Mínima (~5-10%)** |
| **Velocidade de Detecção** | ~100ms | **~10ms** |
| **Vida útil do SSD** | Reduzida (Escrita constante) | **Preservada (Via tmpfs)** |

**Vencedor: Configuração com Aceleração de Hardware.**

---

> **Dica de Senior:** Como você tem um filho de 4 anos que quer aprender a fazer jogos, configurar esse NVR é uma ótima oportunidade para mostrar a ele como a "mágica" da visão computacional funciona na prática!

**Deseja que eu te ajude a ajustar as zonas de detecção no `config.yml` para evitar alarmes falsos agora que o sistema está subindo?**
