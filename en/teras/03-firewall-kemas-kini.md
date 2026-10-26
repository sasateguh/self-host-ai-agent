<!-- generated from kandungan/en/teras/03-firewall-kemas-kini.md by alat/bina.py: edit the template, not this file -->
# 3. Firewall and automatic updates

**Short answer:** install the latest updates, then turn on `ufw` so that only SSH can reach the server from outside,
and turn on `unattended-upgrades` so security fixes install themselves every day. The steps start a temporary web
server on port 8080 and check it from your computer before and after the firewall, so you see
the firewall block a port that is really listening.

Tested on: `ubuntu:24.04` (VM), 2026-10-25.

Run these steps as the user from chapter 2 (`ssh ejen@203.0.113.10`). Steps marked
"on your computer" run in a terminal on your own machine.

## 1. Install updates

If the last line says a reboot is required, run `sudo reboot`, wait a minute and log in again.

```bash
sudo apt-get update
sudo apt-get -y upgrade
if [ -f /var/run/reboot-required ]; then echo "A reboot is required to finish the update."; fi
```

## 2. Start a temporary test server

This serves an empty folder on port 8080, the port an agent might listen on later.

```bash
sudo systemd-run --unit=firewall-test python3 -m http.server 8080 --directory /srv
for _ in $(seq 20); do curl -fsS -o /dev/null http://127.0.0.1:8080/ && break; sleep 1; done
curl -fsS -o /dev/null -w 'test server: HTTP %{http_code}\n' http://127.0.0.1:8080/
```

## 3. Check it from outside (on your computer)

Without a firewall, anyone can reach it.

```bash
nc -z -w 5 203.0.113.10 8080 && echo "port 8080 reachable from outside (no firewall yet)"
```

## 4. Turn on the firewall

The rules block every incoming connection except SSH, and allow everything outgoing (updates, the model provider,
Telegram). Allow SSH before `ufw enable`, or the firewall cuts off your own session.

```bash
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw --force enable
sudo ufw status verbose
```

## 5. Check again (on your computer)

The test server is still running, but the port is now blocked from outside, while SSH stays open.

```bash
if nc -z -w 5 203.0.113.10 8080; then
  echo "port 8080 is still reachable: the firewall is not blocking it"
  exit 1
fi
echo "port 8080 blocked from outside"
nc -z -w 5 203.0.113.10 22 && echo "port 22 (SSH) still open"
```

Chapter 5 opens ports 80 and 443 for HTTPS. The agent itself never needs an open
port: the reverse proxy reaches it on the server. Docker can publish ports past `ufw`; chapter 4 shows how to avoid
that.

## 6. Stop the test server

```bash
sudo systemctl stop firewall-test
```

## 7. Turn on automatic security updates

`unattended-upgrades` installs security fixes once a day. The two settings below turn on the daily package list
refresh and the upgrade itself. The dry run at the end shows what it would do now, without changing anything.

```bash
sudo apt-get install -y unattended-upgrades
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
apt-config dump APT::Periodic::Unattended-Upgrade
systemctl is-enabled apt-daily-upgrade.timer
sudo unattended-upgrade --dry-run
echo "unattended upgrades: dry run passed"
```

Some fixes, such as a new kernel, only take effect after a reboot. Check for `/var/run/reboot-required` when you log in,
or read chapter 9 for monitoring that tells you.
