```bash
mkdir -p /viseron/config
mkdir -p /viseron/recordings
```


/viseron/docker-compose.yml
```yaml
services:
  viseron:
    depends_on:
      - compreface
    image: roflcoopter/viseron:cuda
    container_name: viseron
    restart: unless-stopped
    privileged: true # Necessário para acesso HW direto em alguns setups LXC
    runtime: nvidia  # Chama o driver que você configurou no Host
    ports:
      - "8888:8888" # Interface Web
    volumes:
      - /opt/viseron/config:/config
      - /opt/viseron/recordings:/recordings
      - /etc/localtime:/etc/localtime:ro
    environment:
      - NVIDIA_ visible_devices=all
      - NVIDIA_DRIVER_CAPABILITIES=all
    shm_size: '2gb' # Importante para o buffer de imagem na RAM

  compreface:
      image: exadel/compreface:latest
      container_name: compreface
      restart: unless-stopped
      ports:
        - "8000:8000" # UI para treinar rostos
      volumes:
        - /opt/viseron/plugins/compreface/data:/var/lib/compreface/data
      environment:
        - POSTGRES_PASSWORD=compreface
```

/viseron/config/config.yaml

```yaml
# --- CONFIGURAÇÃO DE SISTEMA ---
logging:
  level: info

# --- BANCO DE DADOS (SQLite Leve) ---
database:
  type: sqlite

# --- NVR (MODO "ZERO GRAVAÇÃO") ---
nvr:
  path: /recordings
  retention:
    days: 0 # Deleta tudo imediatamente

# --- PROCESSAMENTO DE VÍDEO (FFmpeg) ---
ffmpeg:
  # Aceleração de Hardware para DECODIFICAR o stream (Alivia CPU)
  hwaccel_args:
    - -hwaccel
    - cuda
    - -hwaccel_output_format
    - cuda

# --- DETECTOR DE OBJETOS (A Mágica) ---
object_detector:
  type: darknet # Usa o framework YOLO integrado
  
  # Caminho dos modelos (ele baixa sozinho na primeira vez)
  model_path: /config/models/yolov7-tiny.weights # O Viseron baixa automático se não tiver
  config_path: /config/models/yolov7-tiny.cfg
  label_path: /config/models/coco.names
  
  # Configuração da GT 1030
  dnn_backend: cuda
  dnn_target: cuda
  
  # O que procurar?
  labels:
    - label: person
      confidence: 0.65 # Confiança
    - label: car
      confidence: 0.70

# --- NOTIFICAÇÃO (MQTT) ---
mqtt:
  broker: 192.168.1.X # <--- SEU IP DO BROKER MQTT
  port: 1883
  username: mqtt_user
  password: mqtt_pass
  home_assistant:
    enable: true # Cria os sensores no HA sozinho!

# --- CONFIGURAÇÃO DO COMPREFACE ---
face_recognition:
  type: compreface
  host: localhost # ou o IP do container compreface
  port: 8000
  recognition_api_key: "MINHA_API_KEY_DO_COMPREFACE" # Você pega isso na UI dele
  train: false # Deixe false, treine pela UI do CompreFace que é melhor

defaults: &nvr_casa
  host: 192.168.X.X
  port: 554
  username: USER_NAME
  password: PASS

  fps: 5
  width: 704
  height: 480

  recorder:
    enable: false
  
  # MQTT padrão
  mqtt:
    enable: true

# --- CÂMERAS (Exemplo para 1 câmera, replique para as 16) ---
cameras:
  - name: rua_honduras
    <<: *nrv_casa
    path: /cam/realmonitor?channel=1&subtype=1&unicast=true

  - name: rua_fritz
    <<: *nrv_casa
    path: /cam/realmonitor?channel=2&subtype=1&unicast=true

  - name: portao
    <<: *nrv_casa
    path: /cam/realmonitor?channel=3&subtype=1&unicast=true
    # Post Processor: Roda DEPOIS de detectar 'person'
    object_detector:
      labels:
        - label: person
          confidence: 0.75
          trigger_recorder: true
          # AQUI LIGAMOS O RECONHECIMENTO
          post_processor: face_recognition

  - name: garagem
    <<: *nrv_casa
    path: /cam/realmonitor?channel=4&subtype=1&unicast=true

  - name: fundo
    <<: *nrv_casa
    path: /cam/realmonitor?channel=5&subtype=1&unicast=true


```
