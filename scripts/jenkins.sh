#!/bin/sh

test -e /bootstraped && exit 0

# Prepare remote access
install --directory /root/.ssh --group root --owner root --mode 0700
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIiP5mkgz60nzBtug8q1oa64xuqnDbTUTPPvQNFGmQJOllOTF1I7ABewcfdY9CUIQkZqieQQYzhSbWhZZCw4FhpYlFos8WE8AMcGphaJIVo3CWXG4RRduic4r6jCXJcshtr/AqD/SMo15Gbm8LRQbiZBT0964nDDrer24POxiFUQb589aXS40bJ1RHeZOUn94r7SZqSb1OPaJ54TAxFUz0CMNi/pZArzGQgnxHIOhKy3laJTKeoXc86JQlSQXsLA3riJqrnbBjz0w3keFjvlYcdSjnYUn8Wy5g3McnBHwoW7Y/bapmTfeWST8cwpWVP8TENPuoVFFN87IP3aike3FH > /root/.ssh/authorized_keys && sed -i -e 's/PermitRootLogin .*/PermitRootLogin without-password/g' /etc/ssh/sshd_config
service sshd restart

# Install software
curl -o /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
yum upgrade
yum install --assumeyes jenkins java-1.8.0-openjdk-devel nginx
systemctl daemon-reload

# generate ssl
SSL_DIR=/etc/nginx/ssl
mkdir -p ${SSL_DIR}
openssl req -newkey rsa:2048 -nodes -keyout ${SSL_DIR}/key.pem -x509 -days 365 -out ${SSL_DIR}/cert.pem -subj "/C=XX/ST=ST/L=XX/O=XX/OU=OU/CN=CN/emailAddress=emailAddress"
#openssl genrsa -out ${SSL_DIR}/key.pem 2048
#openssl rsa -in ${SSL_DIR}/key.pem -pubout -out ${SSL_DIR}/cert.pem


# Install docker
curl -fsSL https://get.docker.com/ | sh

echo '''
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Load modular configuration files from the /etc/nginx/conf.d directory.
    # See http://nginx.org/en/docs/ngx_core_module.html#include
    # for more information.
    include /etc/nginx/conf.d/*.conf;
}
''' > /etc/nginx/nginx.conf

echo """
server {
  listen *:80 default;


  server_name           _;


  access_log            /var/log/nginx/jenkins.access.log main;
  error_log             /var/log/nginx/jenkins.error.log;

  location / {
    proxy_pass http://localhost:8080;
  }
}
""" > /etc/nginx/conf.d/jenkins.conf

# need to add auth or migrate to the normal registry (Harbor, Google registry etc)
echo """
server {
  listen *:443 default http2 ssl;

  ssl_certificate           /etc/nginx/ssl/cert.pem;
  ssl_certificate_key       /etc/nginx/ssl/key.pem;

  server_name           _;

  access_log            /var/log/nginx/docker.access.log main;
  error_log             /var/log/nginx/docker.error.log;

  location / {
    proxy_pass http://localhost:5000;
  }
}
""" > /etc/nginx/conf.d/docker.conf

mkdir /etc/docker

echo '''
{
  "insecure-registries" : ["localhost:5000"]
}
''' > /etc/docker/daemon.json


systemctl restart nginx

systemctl start docker
systemctl enable docker

systemctl start jenkins
systemctl enable jenkins

# need to move to systemd unit file
docker run -d -p 5000:5000 --restart=always --name registry registry:2

touch /bootstraped