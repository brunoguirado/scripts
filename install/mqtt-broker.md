#MQTT

1. Instalação
```bash
apt update && apt upgrade -y
apt install -y mosquitto mosquitto-clients
```

2. Configuração de Segurança (Crucial)
O Mosquitto vem "trancado" por padrão. Vamos abrir a porta e exigir senha.

```bash
# Apaga a config padrão e cria uma nova limpa
echo "listener 1883" > /etc/mosquitto/conf.d/default.conf
echo "allow_anonymous false" >> /etc/mosquitto/conf.d/default.conf
echo "password_file /etc/mosquitto/passwd" >> /etc/mosquitto/conf.d/default.conf
```
3. Criar Usuário e Senha
4. 
```bash
# Cria o arquivo de senha e adiciona o usuário 'admin' (ou o nome que quiser)
mosquitto_passwd -c /etc/mosquitto/passwd admin
# (Digite a senha duas vezes quando pedir)
```


4. Habilitar e Rodar
```bash
systemctl enable mosquitto
systemctl restart mosquitto
```
