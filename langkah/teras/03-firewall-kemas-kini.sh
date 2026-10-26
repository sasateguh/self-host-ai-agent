#!/usr/bin/env bash
# Bab teras 3: kemas kini, firewall ufw (hanya SSH masuk, diukur dari luar), kemas kini keselamatan automatik.
# Jalankan: python3 alat/uji.py teras/03-firewall-kemas-kini
# @perlu vm

# @langkah kemas-kini
sudo apt-get update
sudo apt-get -y upgrade
if [ -f /var/run/reboot-required ]; then echo "A reboot is required to finish the update."; fi

# @langkah pelayan-cuba
sudo systemd-run --unit=firewall-test python3 -m http.server 8080 --directory /srv
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'test server: HTTP %{http_code}\n' http://127.0.0.1:8080/

# @langkah sebelum luar
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside (no firewall yet)"

# @langkah ufw
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose

# @langkah selepas luar
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable: the firewall is not blocking it"
  exit 1
fi
echo "port 8080 blocked from outside"
nc -z -w 5 203.0.113.10 22 && echo "port 22 (SSH) still open"

# @langkah henti-pelayan-cuba
sudo systemctl stop firewall-test

# @langkah kemas-kini-automatik
sudo apt-get install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
apt-config dump APT::Periodic::Unattended-Upgrade
systemctl is-enabled apt-daily-upgrade.timer
sudo unattended-upgrade --dry-run
echo "unattended upgrades: dry run passed"
