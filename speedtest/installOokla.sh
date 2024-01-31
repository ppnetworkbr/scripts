#!/bin/bash

# Verificar conectividade com a internet
wget -q --spider http://google.com

if [ $? -eq 0 ]; then
    echo "Online"
else
    echo "Offline"
    exit 1
fi

# Verificar conectividade IPv6
if ping6 -c 1 google.com > /dev/null 2>&1; then
    echo "IPv6 está funcionando."
else
    echo "IPv6 não está funcionando."
    exit 1
fi

# Adicionar configurações ao /etc/sysctl.conf
echo "
# Kernel deve tentar manter o máximo possível de dados em memória principal 
vm.swappiness = 5
# Evitar que o sistema fique sobrecarregado com muitos dados sujos na memória.
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
# Aumentar o número máximo de conexões simultâneas
net.core.somaxconn = 65535
# Aumentar o tamanho máximo do buffer de recepção e transmissão de rede
net.ipv4.tcp_mem = 4096 87380 16777216
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
# Melhorar o desempenho da conexão e a evitar congestionamentos
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_timestamps = 1
# Reduzir o tempo limite de conexão TCP
net.ipv4.tcp_fin_timeout = 15
# Ativar o escalonamento de fila de recepção de pacotes de rede
net.core.netdev_max_backlog = 8192
# Aumentar o número máximo de portas locais que podem ser usadas
net.ipv4.ip_local_port_range = 1024 65535
" >> /etc/sysctl.conf

# Carregar os módulos
modprobe -a tcp_illinois
echo "tcp_illinois" >> /etc/modules

modprobe -a tcp_westwood
echo "tcp_westwood" >> /etc/modules

modprobe -a tcp_htcp
echo "tcp_htcp" >> /etc/modules

if ! command -v docker &> /dev/null
then
    echo "Docker não encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    mv get-docker.sh /tmp
    sh /tmp/get-docker.sh
fi

# Fazer login no Docker
echo "Por favor, insira suas credenciais do Docker:"
read -p 'Usuário: ' uservar
read -sp 'Senha: ' passvar
docker login login ghcr.io --username $uservar --password $passvar

# Baixar a imagem
docker ghcr.io/ppnetworkbr/speedtest-ookla:main

# Solicitar o domínio e o email
read -p 'Domínio: ' domain
read -p 'Email: ' email

# Subir o container
docker run -d --name PPNETWORK-SPEEDTEST-OOKLA -p 8080:8080 -p 443:443 -p 80:80 -e DOMAIN=$domain -e EMAIL=$email --hostname ppnetwork-speedtest-ookla ghcr.io/ppnetworkbr/speedtest-ookla:main

# Verificar se o domínio aponta para o mesmo IP que a interface do Linux
ip=$(curl -4 icanhazip.com)
domain_ip=$(dig +short $domain)
if [ "$ip" == "$domain_ip" ]; then
    echo "O domínio está apontando corretamente."
else
    echo "O domínio não está apontando para o IP correto."
    exit 1
fi

# Verificar se o domínio aponta para o mesmo IP IPv6 que a interface do Linux
ip6=$(curl -6 icanhazip.com)
domain_ip6=$(dig +short $domain AAAA)
if [ "$ip6" == "$domain_ip6" ]; then
    echo "O domínio IPv6 está apontando corretamente."
else
    echo "O domínio IPv6 não está apontando para o IP correto."
    exit 1
fi