# Atualiza repositórios e dependências
```bash
apt update && apt install -y ca-certificates curl gnupg
```


# Adiciona a chave GPG oficial do Docker
```bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
```

# Configura o repositório estável
```bash
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
```


# Instala o Docker Engine e Docker Compose
```bash
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

# Se tiver CUDA/Nvidia Configurar o Docker para usar a GPU
```bash
nvidia-ctk runtime configure --runtime=docker && systemctl restart docker
```
