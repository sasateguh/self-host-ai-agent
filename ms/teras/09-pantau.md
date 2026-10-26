<!-- generated from kandungan/ms/teras/09-pantau.md by alat/bina.py: edit the template, not this file -->
# 9. Pemantauan dan kemas kini

**Jawapan ringkas:** satu skrip kecil menyemak cakera, ingatan, servis yang gagal, bekas yang rosak dan but semula yang
tertunda setiap 15 minit, dan menghantar mesej Telegram kepada anda bila senarai itu berubah, termasuk "all clear" bila
masalah sudah hilang. Bekas dikemas kini dengan menukar tag versi yang dipin, menarik imej dan mencipta semula bekas;
berundur ialah langkah yang sama dengan tag lama. Langkah di bawah merosakkan satu servis dengan sengaja untuk melihat
amaran, kemudian mengemas kini dan mengundurkan satu bekas.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah melalui bab 3 (kemas kini keselamatan
automatik), bab 4 (Docker) dan bab 7 (bot Telegram). Larian ujian menghantar mesejnya kepada pengganti API Telegram.

## 1. Skrip semakan

Dua had di bahagian atas skrip ialah peratus; ubah ikut pelayan anda. `check-server print` hanya mencetak senarai semasa
dan tidak menghantar apa-apa.

```bash
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
```

Skrip mengingati senarai terakhir yang dihantarnya dalam `/var/lib/check-server/last`, jadi masalah yang berlarutan
sepanjang malam memberi anda satu mesej, bukan satu setiap 15 minit.

## 2. Jalankan setiap 15 minit

```bash
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
```

## 3. Cuba satu amaran

Ini memulakan servis sementara yang gagal dengan sengaja, kemudian menjalankan semakan. Mesej Telegram menyenaraikan
`check-demo.service` sebagai gagal, dan senarai yang disimpan menunjukkan perkara sama.

```bash
sudo systemd-run --unit=check-demo --wait sh -c 'exit 3' || echo "check-demo failed on purpose"
sudo systemctl start check-server.service
sudo cat /var/lib/check-server/last
sudo grep check-demo /var/lib/check-server/last >/dev/null
```

## 4. Padamkan amaran

Menyuruh systemd melupakan servis yang gagal itu menghilangkan masalah. Semakan seterusnya menghantar "all clear".

```bash
sudo systemctl reset-failed check-demo.service
sudo systemctl start check-server.service
sudo check-server print
test "$(sudo grep -c check-demo /var/lib/check-server/last)" = 0
```

Bila amaran sebenar sampai, lihat servis itu dengan `systemctl status <nama>` dan `journalctl -u <nama> -n 50`.
Untuk bekas, guna `sudo docker logs --tail 50 <nama>`. Untuk "a reboot is needed", jalankan `sudo reboot` pada waktu
lapang.

## 5. Pin versi bekas

Kemas kini keselamatan Ubuntu dipasang sendiri (bab 3). Bekas tidak: ia hanya berubah bila anda mengubahnya. Tulis tag
versi yang tepat dalam `compose.yaml` (jangan `latest`), supaya anda sentiasa tahu apa yang berjalan dan boleh berundur.
Contoh ini menjalankan keluaran Alpine yang lebih lama:

```bash
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
```

## 6. Kemas kini

Baca nota keluaran projek itu dahulu, kemudian tukar tag, tarik imej baharu dan cipta semula bekas. Semakan selepas itu
mengesahkan tiada apa yang rosak.

```bash
cd /srv/update-demo
sudo sed -i 's/alpine:3.19/alpine:3.20/' compose.yaml
sudo docker compose pull
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release
sudo check-server print
```

Ambil backup (bab 6) sebelum mengemas kini apa-apa yang menyimpan data.

## 7. Berundur

Jika versi baharu bermasalah, letak semula tag lama dan cipta semula bekas. Imej itu masih ada di pelayan, jadi ini
berfungsi tanpa internet.

```bash
cd /srv/update-demo
sudo sed -i 's/alpine:3.20/alpine:3.19/' compose.yaml
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release
```

## 8. Kemas

Buang projek contoh dan imejnya. Skrip semakan dan pemasanya kekal.

```bash
cd /srv/update-demo
sudo docker compose down
cd /
sudo rm -r /srv/update-demo
sudo docker image rm alpine:3.19 alpine:3.20
```
