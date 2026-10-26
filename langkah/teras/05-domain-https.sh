#!/usr/bin/env bash
# Bab teras 5: nama domain menghala ke VPS, Caddy sebagai proksi terbalik dengan sijil HTTPS automatik, ejen kekal pada
# 127.0.0.1. Pelayan sudah melalui bab 3 (ufw aktif). Dalam ujian, rangkaian meniru DNS + Let's Encrypt (Pebble).
# Jalankan: python3 alat/uji.py teras/05-domain-https
# @perlu vm ca
# @selepas teras/03-firewall-kemas-kini

# @langkah dns luar
ping -c 1 agent.example.com

# @langkah ejen-cuba
sudo install -d /srv/agent-test
echo "hello from the agent" | sudo tee /srv/agent-test/index.html >/dev/null
sudo systemd-run --unit=agent-test python3 -m http.server 8080 --bind 127.0.0.1 --directory /srv/agent-test
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS http://127.0.0.1:8080/

# @langkah pasang-caddy
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
sudo chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install -y caddy
caddy version
systemctl is-active caddy

# @langkah firewall
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw status

# @langkah caddyfile
sudo tee /etc/caddy/Caddyfile >/dev/null <<'EOF'
{
	email admin@example.com
}

agent.example.com {
	reverse_proxy 127.0.0.1:8080
}
EOF
sudo caddy validate --config /etc/caddy/Caddyfile 2>&1 | tail -n 1
sudo systemctl reload caddy

# @langkah sijil
for _ in $(seq 60); do
  sudo journalctl -u caddy --no-pager | grep 'certificate obtained successfully' >/dev/null && break
  sleep 2
done
sudo journalctl -u caddy --no-pager -o cat | grep 'certificate obtained successfully' | tail -n 1

# @langkah https luar
curl -fsS https://agent.example.com/
curl -sS -o /dev/null -w 'http://  -> HTTP %{http_code} %{redirect_url}\n' http://agent.example.com/
curl -fsS -o /dev/null -w 'https:// -> HTTP %{http_code}, certificate check %{ssl_verify_result} (0 = valid)\n' https://agent.example.com/

# @langkah port-dalaman luar
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is reachable from outside"
  exit 1
fi
echo "port 8080 blocked from outside: only Caddy reaches the agent"

# @langkah henti-ejen-cuba
sudo systemctl stop agent-test
sudo rm -r /srv/agent-test
