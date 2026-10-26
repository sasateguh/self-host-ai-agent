#!/usr/bin/env bash
# Bab teras 9: pantau + kemas kini. Skrip semakan (cakera, ingatan, servis gagal, bekas bermasalah, but semula diperlukan)
# dijalankan pemasa systemd setiap 15 minit dan menghantar mesej Telegram hanya bila keadaan BERUBAH. Amaran dicetuskan
# dengan sengaja (servis gagal) dan dipadam. Kemas kini bekas = tukar tag dipin, tarik, cipta semula; undur = tag lama.
# Pelayan sudah melalui bab 3 (ufw, kemas kini automatik), bab 4 (Docker) dan bab 7 (/etc/agent/telegram.env).
# Jalankan: python3 alat/uji.py teras/09-pantau
# @perlu vm palsu
# @selepas teras/03-firewall-kemas-kini teras/04-docker teras/07-telegram

# @langkah skrip
sudo tee /usr/local/sbin/check-server >/dev/null <<'EOF'
#!/bin/sh
# Checks the server and sends a Telegram message when the list of problems changes,
# including "all clear" when they are gone. "check-server print" only prints the list.
set -eu
DISK_LIMIT=85     # percent of / in use
MEMORY_LIMIT=90   # percent of memory in use

problems=""
add() { problems="$problems- $1
"; }

disk=$(df --output=pcent / | tail -n 1 | tr -dc 0-9)
[ "$disk" -le "$DISK_LIMIT" ] || add "disk / is ${disk}% full"

memory=$(free | awk '/^Mem:/ {printf "%d", ($2 - $7) * 100 / $2}')
[ "$memory" -le "$MEMORY_LIMIT" ] || add "memory is ${memory}% in use"

failed=$(systemctl list-units --state=failed --plain --no-legend | awk '{printf "%s ", $1}')
[ -z "$failed" ] || add "failed services: $failed"

if command -v docker >/dev/null; then
  bad=$( { docker ps --filter status=restarting --format '{{.Names}}'
           docker ps --filter health=unhealthy --format '{{.Names}}'
           docker ps -a --filter status=exited --format '{{.Names}} {{.Status}}' | grep -v 'Exited (0)' || true
         } | awk '{printf "%s ", $1}')
  [ -z "$bad" ] || add "containers not running properly: $bad"
fi

[ ! -f /var/run/reboot-required ] || add "a reboot is needed to finish security updates"

if [ "${1:-}" = print ]; then
  printf '%s' "${problems:-no problems found
}"
  exit 0
fi

mkdir -p /var/lib/check-server
last=$(cat /var/lib/check-server/last 2>/dev/null || true)
[ "$(printf '%s' "$problems")" != "$last" ] || exit 0

if [ -n "$problems" ]; then
  text="$(hostname) needs attention:
$problems"
else
  text="$(hostname): all clear"
fi
. /etc/agent/telegram.env
printf 'url = "%s/bot%s/sendMessage"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" \
  | curl -fsS -K - -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="$text" >/dev/null
printf '%s' "$problems" > /var/lib/check-server/last
EOF
sudo chmod 755 /usr/local/sbin/check-server
sudo check-server print

# @langkah jadual
sudo tee /etc/systemd/system/check-server.service >/dev/null <<'EOF'
[Unit]
Description=Check the server and report problems to Telegram

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/check-server
EOF
sudo tee /etc/systemd/system/check-server.timer >/dev/null <<'EOF'
[Unit]
Description=Check the server every 15 minutes

[Timer]
OnBootSec=5min
OnCalendar=*:0/15

[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now check-server.timer
systemctl list-timers check-server.timer --no-pager

# @langkah cuba-amaran
sudo systemd-run --unit=check-demo --wait sh -c 'exit 3' || echo "check-demo failed on purpose"
sudo systemctl start check-server.service
sudo cat /var/lib/check-server/last
sudo grep check-demo /var/lib/check-server/last >/dev/null

# @langkah padam-amaran
sudo systemctl reset-failed check-demo.service
sudo systemctl start check-server.service
sudo check-server print
test "$(sudo grep -c check-demo /var/lib/check-server/last)" = 0

# @langkah versi-dipin
sudo install -d /srv/update-demo
sudo tee /srv/update-demo/compose.yaml >/dev/null <<'EOF'
services:
  app:
    image: alpine:3.19
    restart: unless-stopped
    command: ["sleep", "infinity"]
EOF
cd /srv/update-demo
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release

# @langkah kemas-kini
cd /srv/update-demo
sudo sed -i 's/alpine:3.19/alpine:3.20/' compose.yaml
sudo docker compose pull
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release
sudo check-server print

# @langkah undur
cd /srv/update-demo
sudo sed -i 's/alpine:3.20/alpine:3.19/' compose.yaml
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release

# @langkah kemas
cd /srv/update-demo
sudo docker compose down
cd /
sudo rm -r /srv/update-demo
sudo docker image rm alpine:3.19 alpine:3.20
