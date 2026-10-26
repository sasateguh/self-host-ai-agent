#!/usr/bin/env bash
# Bab teras 4: Docker dari repositori rasmi, log berputar, dan port yang Docker terbitkan MELEPASI ufw (diukur dari luar);
# terbit pada 127.0.0.1 sahaja menutupnya. Pelayan sudah melalui bab 3 (ufw aktif, hanya SSH masuk).
# Jalankan: python3 alat/uji.py teras/04-docker
# @perlu vm
# @selepas teras/03-firewall-kemas-kini

# @langkah pasang
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker version --format 'Docker Engine {{.Server.Version}}'
sudo docker compose version

# @langkah log
sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
sudo docker info --format 'log driver: {{.LoggingDriver}}'

# @langkah hello
sudo docker run --rm hello-world | grep 'Hello from Docker!'

# @langkah terbit-semua
sudo ufw status | sed -n 1p
sudo docker run -d --name port-test -p 8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
sudo docker port port-test

# @langkah terbit-semua-luar luar
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside, although ufw only allows SSH"

# @langkah terbit-tempatan
sudo docker rm -f port-test
sudo docker run -d --name port-test -p 127.0.0.1:8080:80 nginx:alpine
for _ in $(seq 30); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'on the server: HTTP %{http_code}\n' http://127.0.0.1:8080/
sudo docker port port-test

# @langkah terbit-tempatan-luar luar
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"

# @langkah compose
sudo docker rm -f port-test
sudo install -d /srv/port-test
sudo tee /srv/port-test/compose.yaml >/dev/null <<'EOF'
services:
  web:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:80"
EOF
cd /srv/port-test
sudo docker compose up -d --wait
sudo docker compose ps --format '{{.Name}}: {{.Ports}}'
curl -fsS -o /dev/null -w 'on the server: HTTP %{http_code}\n' http://127.0.0.1:8080/

# @langkah compose-luar luar
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside"

# @langkah kemas
cd /srv/port-test
sudo docker compose down
cd /
sudo rm -r /srv/port-test
sudo docker image rm nginx:alpine hello-world
echo "containers left: $(sudo docker ps -aq | wc -l)"
