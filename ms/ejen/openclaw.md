<!-- generated from kandungan/ms/ejen/openclaw.md by alat/bina.py: edit the template, not this file -->
# OpenClaw di pelayan anda

**Jawapan ringkas:** jalankan imej Docker rasmi OpenClaw, dipin pada satu versi yang diuji, dengan Docker Compose.
OpenClaw membaca kunci API model, token bot Telegram dan token gateway miliknya daripada fail (bab 7 dan 8), bercakap
dengan penyedia model serasi OpenAI, dan hanya menjawab akaun Telegram anda sendiri. Backup dengan arahan backup
miliknya sendiri serta restic, dan kemas kini dengan menukar satu baris.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26, dengan OpenClaw v2026.10.7 (dikeluarkan
2026-10-24).

OpenClaw ialah pembantu AI peribadi sumber terbuka (lesen MIT, kod sumber di
https://github.com/openclaw/openclaw, dokumentasi di https://docs.openclaw.ai/). Satu proses yang sentiasa berjalan,
dipanggil gateway, menyambungkannya kepada aplikasi sembang seperti Telegram dan kepada penyedia model anda. Bab ini
mengikut dokumentasi Docker, Telegram, penyedia, kunci dan backup projek itu sendiri untuk versi di atas.

Jalankan langkah ini sebagai pengguna dari bab 2, atas pelayan yang sudah melalui bab 3 (firewall), 4 (Docker),
6 (backup), 7 (bot Telegram) dan 8 (kunci API model). Larian ujian memakai penyedia model tiruan dan API Telegram
tiruan, kunci rekaan, dan mesej ujian sebagai ganti mesej yang ditaip di telefon.

Sediakan pelayan dengan sekurang-kurangnya 4 GB memori. Dalam ujian, bekas OpenClaw memakai lebih kurang 2 GB selepas
jawapan pertamanya, dan pada mesin ujian yang hanya ada 2 GB, setiap arahan mengambil masa beberapa minit.

## 1. Muat turun keluaran sebelumnya dahulu

Nama imej berakhir dengan tag dan digest (`sha256:...`). Tag ialah nama versi; digest ialah cap jari imej tepat yang
diuji, jadi Docker menolak imej lain, walaupun seseorang mengalihkan tag itu kemudian. Imej datang dari GitHub Container
Registry, yang projek ini guna untuk keluarannya. Saiz muat turun setiap satu lebih kurang 700 MB.

Bab ini bermula dengan keluaran sebelum versi yang diuji, 2026.10.6, supaya langkah 11 ialah
kemas kini sebenar ke 2026.10.7 dan undur sebenar. Anda berakhir pada 2026.10.7. Kalau
anda mahu bermula terus dengan versi yang diuji, guna tag dan digestnya dari langkah 11 dalam langkah 1 dan 4.

```bash
sudo docker pull ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
sudo docker run --rm ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b node openclaw.mjs --version
```

## 2. Tulis fail tetapan

OpenClaw menyimpan tetapan, perbualan dan ingatannya dalam satu folder keadaan, di sini `/srv/openclaw/data`. Bekas
berjalan sebagai pengguna dengan ID 1000, jadi folder itu milik ID tersebut. Folder kedua, `/srv/openclaw/backups`, akan
menyimpan arkib backup (langkah 9).

Baris pertama mencipta token gateway: kata laluan rawak yang melindungi antara muka kawalan gateway, disimpan bersama
kunci dari bab 8 dan hanya boleh dibaca oleh root.

Fail tetapan kemudian menyatakan:

- `gateway`: dengar pada `127.0.0.1` sahaja, dan wajibkan token gateway.
- `secrets.providers`: dua fail yang setiap satunya memegang satu nilai, iaitu kunci model dan token gateway. Fail
  tetapan menunjuk kepada fail itu dan tidak pernah mengandungi nilainya.
- `models`: penyedia serasi OpenAI di `OPENAI_BASE_URL` (alamat sama seperti bab 8; tetapkan dahulu kalau penyedia anda
  memberi alamat), dengan kunci daripada fail.
- `channels.telegram`: baca token bot daripada fail, dan dengan `dmPolicy: "allowlist"` jawab ID sembang yang disimpan
  dalam bab 7 sahaja. Orang lain yang menjumpai bot itu tidak mendapat apa-apa.

Secara lalai OpenClaw enggan menyambung ke alamat dalam rangkaian peribadi, sebagai benteng supaya permintaan tidak
dilencongkan ke mesin anda sendiri. Dua semakan `if` hanya melonggarkannya bila anda memakai alamat sebegitu: alamat
model yang bermula dengan `http://` (contohnya pelayan model dalam rangkaian anda sendiri) atau alamat Telegram yang
bukan milik Telegram (pelayan Bot API tempatan). Dengan penyedia dan Telegram biasa, kedua-duanya tidak menambah
apa-apa.

```bash
sudo install -d -m 700 /srv/openclaw
sudo install -d -m 700 -o 1000 -g 1000 /srv/openclaw/data /srv/openclaw/backups
sudo install -m 600 /dev/null /etc/agent/openclaw-gateway.token
sudo sh -c 'openssl rand -hex 32 > /etc/agent/openclaw-gateway.token'
. <(sudo cat /etc/agent/telegram.env)
sudo tee /srv/openclaw/data/openclaw.json >/dev/null <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "loopback",
    "port": 18789,
    "auth": { "mode": "token", "token": { "source": "file", "provider": "gateway_token", "id": "value" } }
  },
  "secrets": {
    "providers": {
      "model_key": { "source": "file", "path": "/run/openclaw/model.key", "mode": "singleValue" },
      "gateway_token": { "source": "file", "path": "/run/openclaw/gateway.token", "mode": "singleValue" }
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "custom": {
        "baseUrl": "${OPENAI_BASE_URL:-https://api.openai.com/v1}",
        "apiKey": { "source": "file", "provider": "model_key", "id": "value" },
        "api": "openai-completions",
        "models": [{ "id": "MODEL_NAME", "name": "MODEL_NAME" }]
      }
    }
  },
  "agents": { "defaults": { "model": { "primary": "custom/MODEL_NAME" } } },
  "channels": {
    "telegram": {
      "enabled": true,
      "tokenFile": "/run/openclaw/telegram.token",
      "dmPolicy": "allowlist",
      "allowFrom": ["$TELEGRAM_CHAT_ID"]
    }
  }
}
EOF
extra='.'
case "${OPENAI_BASE_URL:-https://api.openai.com/v1}" in
  http://*) extra="$extra | .models.providers.custom.request.allowPrivateNetwork = true" ;;
esac
if [ "$TELEGRAM_API_URL" != https://api.telegram.org ]; then
  extra="$extra | .channels.telegram.apiRoot = \$tg | .channels.telegram.network.dangerouslyAllowPrivateNetwork = true"
fi
sudo jq --arg tg "$TELEGRAM_API_URL" "$extra" /srv/openclaw/data/openclaw.json | sudo tee /srv/openclaw/data/openclaw.json.new >/dev/null
sudo mv /srv/openclaw/data/openclaw.json.new /srv/openclaw/data/openclaw.json
sudo chown 1000:1000 /srv/openclaw/data/openclaw.json
sudo chmod 600 /srv/openclaw/data/openclaw.json
sudo cat /srv/openclaw/data/openclaw.json
```

## 3. Pilih model

Arahan ini menyenaraikan model yang boleh dipakai dengan kunci anda, kemudian menunggu anda menaip satu nama dan menekan
Enter.

```bash
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|MODEL_NAME|$model|g" /srv/openclaw/data/openclaw.json
```

## 4. Mulakan OpenClaw dengan Docker Compose

Fail Compose memberi bekas itu fail dari bab 7 dan 8 serta token gateway di bawah `/run/secrets/`. Salinan itu milik
root, sama seperti fail asal, dan OpenClaw berjalan sebagai pengguna biasa, jadi bekas bermula sebagai root seketika:
baris `entrypoint` menyalin tiga nilai itu ke folder dalam ingatan sahaja (`tmpfs`) yang hanya boleh dibaca oleh
pengguna OpenClaw, memastikan folder keadaan dan folder backup milik pengguna itu, kemudian bertukar kepadanya dengan
`setpriv` dan memulakan imej seperti biasa. Semakan kesihatan imej juga berjalan melalui `setpriv`, jadi tiada apa dalam
folder keadaan pernah dicipta oleh root. Atas sebab yang sama, setiap `docker exec` dalam bab ini memakai `-u node`.
Tiada apa yang ditulis ke cakera, dan nilainya tidak pernah muncul dalam `docker inspect` (bab 8 menunjukkan sebab ia
penting).

`network_mode: host` dengan gateway terikat pada `127.0.0.1` bermakna tiada port diterbitkan, jadi Docker tidak menambah
peraturan firewall sendiri (bab 4). `cap_drop` dan `no-new-privileges` diambil dari fail Compose projek itu sendiri.

```bash
sudo tee /srv/openclaw/compose.yaml >/dev/null <<'EOF'
services:
  openclaw:
    image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
    container_name: openclaw
    restart: unless-stopped
    # Nothing is published: the gateway listens on 127.0.0.1 only and makes outgoing connections to Telegram.
    network_mode: host
    environment:
      HOME: /home/node
      TZ: UTC
    volumes:
      - ./data:/home/node/.openclaw
      - ./backups:/home/node/backups
    tmpfs:
      - /run/openclaw:mode=0700,uid=1000,gid=1000
    secrets:
      - model_key
      - telegram_env
      - gateway_token
    cap_drop:
      - NET_RAW
      - NET_ADMIN
    security_opt:
      - no-new-privileges:true
    # Starts as root only to copy the three secret files (readable by root alone) into memory for the image's
    # "node" user, then drops to that user and starts the image as usual.
    user: root
    entrypoint:
      - /bin/sh
      - -c
      - |
        set -e
        cat /run/secrets/model_key > /run/openclaw/model.key
        cat /run/secrets/gateway_token > /run/openclaw/gateway.token
        (. /run/secrets/telegram_env; printf '%s' "$$TELEGRAM_BOT_TOKEN") > /run/openclaw/telegram.token
        chown node:node /run/openclaw/*
        chmod 400 /run/openclaw/*
        chown -R node:node /home/node/.openclaw /home/node/backups
        exec setpriv --reuid=node --regid=node --init-groups tini -s -- node /app/docker-entrypoint.mjs "$$@"
      - openclaw
    command: ["node", "openclaw.mjs", "gateway"]
    # The image's own health check, run as the same "node" user (the container's default user is root, see above).
    healthcheck:
      test: ["CMD", "setpriv", "--reuid=node", "--regid=node", "--init-groups", "node", "dist/docker-healthcheck.js"]
secrets:
  model_key:
    file: /etc/agent/model.key
  telegram_env:
    file: /etc/agent/telegram.env
  gateway_token:
    file: /etc/agent/openclaw-gateway.token
EOF
cd /srv/openclaw
sudo docker compose up -d
sudo docker compose ps
```

`restart: unless-stopped` memulakan semula OpenClaw selepas ranap atau but semula.

## 5. Tunggu sambungan Telegram

Permulaan pertama mengambil masa satu atau dua minit: OpenClaw menyemak dan menyediakan folder keadaannya sebelum
gateway dibuka. Arahan ini menunggu semakan kesediaan gateway, kemudian baris log yang menyatakan sambungan Telegram
sudah bermula. Kalau gateway belum sedia selepas lima minit, ia memaparkan status bekas dan baris log terakhir tanpa
hiasannya, yang biasanya menamakan masalah itu.

```bash
cd /srv/openclaw
if ! timeout 300 sh -c 'until curl -fsS http://127.0.0.1:18789/readyz >/dev/null 2>&1; do sleep 5; done'; then
  sudo docker compose ps -a --format '{{.Name}} {{.Status}}'
  sudo docker compose logs --no-log-prefix | grep -v -e '^[│◇├└┌ ]' -e '^$' | cut -c 1-200 | tail -n 15
  exit 1
fi
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
sudo docker compose ps --format '{{.Name}} {{.Status}}'
```

## 6. Hantar mesej pertama

Hantar apa-apa mesej kepada bot anda dari telefon. Arahan ini menunggu baris log yang menyatakan OpenClaw sudah menghantar
jawapannya, kemudian memaparkan baris untuk mesej masuk anda. Jawapan sampai dalam Telegram.

OpenClaw juga menjalankan semakan latar berkala dan mungkin menghantar nota pendek pertama tentangnya; nota itu
menyebut tetapan yang mematikannya. Larian ujian juga menerima nota itu.

```bash
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160
sudo docker stats --no-stream --format '{{.Name}} memory {{.MemUsage}}' openclaw
```

## 7. Pastikan kunci dan token tidak bocor

Arahan ini menulis kunci model, token bot dan token gateway ke fail yang hanya boleh dibaca root buat seketika, mengira
berapa baris `docker inspect`, log bekas dan fail dalam folder keadaan yang mengandungi mana-mana nilai itu, kemudian
memadam fail tersebut. Ketiga-tiga kiraan mesti sifar.

```bash
cd /srv/openclaw
sudo sh -c 'umask 077; . /etc/agent/telegram.env; { printf "%s\n" "$TELEGRAM_BOT_TOKEN"; cat /etc/agent/model.key; echo; cat /etc/agent/openclaw-gateway.token; } > /root/secrets.txt'
inspect="$(sudo docker inspect openclaw | sudo grep -c -F -f /root/secrets.txt || true)"
logs="$(sudo docker compose logs | sudo grep -c -F -f /root/secrets.txt || true)"
files="$(sudo grep -rlsF -D skip -f /root/secrets.txt data | wc -l || true)"
sudo rm /root/secrets.txt
echo "lines with the key or a token: docker inspect $inspect, logs $logs, files in data/ $files"
test "$inspect $logs $files" = "0 0 0"
```

## 8. Pastikan tiada apa-apa terbuka ke internet

OpenClaw bercakap dengan Telegram dan penyedia model anda melalui sambungan keluar, jadi ia tidak perlukan port terbuka
atau alamat web. Gateway mendengar pada port 18789, terikat pada `127.0.0.1`:

```bash
sudo ss -ltnp | grep ':18789 '
```

Jalankan ini di komputer anda sendiri untuk memastikan port itu tidak boleh dicapai dari luar:

```bash
! nc -z -w 3 203.0.113.10 18789
echo "the agent's gateway port is closed from outside"
```

Anda tidak perlukan laman Caddy dari bab 5 untuk OpenClaw. Gateway juga menyediakan panel kawalan web yang boleh menukar
tetapan dan menjalankan arahan. Kekalkan ia pada `127.0.0.1` dan capai melalui terowong SSH dengan token gateway; jangan
terbitkannya pada port atau di belakang alamat web awam.

## 9. Masukkan OpenClaw ke backup harian

Menyalin pangkalan data semasa ejen menulis kepadanya boleh menghasilkan salinan rosak. `openclaw backup create`
membuat arkib folder keadaan yang konsisten, menyemaknya dengan `--verify`, dan tidak menulis nilai kunci ke dalamnya.
Arahan ini menambahnya ke skrip backup harian dari bab 6, sebelum restic berjalan: ia memadam arkib semalam, menulis
yang baharu, dan restic menyimpan arkib serta fail Compose. Kemudian ia menjalankan backup sekali dan menyenaraikan apa
yang disimpan restic.

```bash
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec -u node openclaw sh -c "rm -f /home/node/backups/*.tar.gz \&\& node dist/index.js backup create --output /home/node/backups --verify >/dev/null"\n& /srv/openclaw/compose.yaml /srv/openclaw/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/openclaw/
```

Kalau ejen lain dari panduan ini sudah mengubah baris `restic backup`, tambah dua baris itu dengan tangan.

## 10. Latih pemulihan

Arahan ini menulis skrip pemulihan kecil, `/usr/local/sbin/restore-openclaw`, dan menjalankannya. Skrip itu
menghentikan OpenClaw, memadam folder keadaan, arkib dan fail Compose, mendapatkan semula arkib dan fail Compose dari
restic, dan membuka arkib dengan `openclaw backup restore` ke dalam folder kosong. OpenClaw tidak pernah memulihkan di
atas data yang sedang hidup, jadi skrip itu kemudian menyalin folder keadaan yang dipulihkan ke tempatnya. Sebelum
gateway dimulakan semula, bekas sekali guna menyenaraikan perbualan dalam folder yang dipulihkan: perbualan dari
langkah 6 kembali. `</dev/null` menghalang bekas sekali guna daripada membaca arahan yang anda tampal selepasnya.

```bash
sudo tee /usr/local/sbin/restore-openclaw >/dev/null <<'EOF'
#!/bin/sh
# Restore OpenClaw from the latest restic snapshot: the Compose file, then the state folder from the backup archive.
set -eu
cd /srv/openclaw
if [ -f compose.yaml ]; then docker compose down; fi
rm -rf /srv/openclaw/data /srv/openclaw/backups /srv/openclaw/compose.yaml
restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target / --include /srv/openclaw
install -d -m 700 -o 1000 -g 1000 /srv/openclaw/data
archive="$(ls /srv/openclaw/backups)"
docker compose run --rm --no-deps openclaw node dist/index.js backup restore "/home/node/backups/$archive" \
  --target /home/node/backups/restored </dev/null | tail -n 1
cp -a /srv/openclaw/backups/restored/*/payload/posix/home/node/.openclaw/. /srv/openclaw/data/
rm -r /srv/openclaw/backups/restored
echo "conversations in the restored state:"
docker compose run --rm --no-deps openclaw node dist/index.js sessions --json </dev/null \
  | jq -r '.sessions[] | "\(.sessionId) \(.status) model=\(.modelProvider)/\(.model)"'
grep 'image:' compose.yaml
docker compose up -d
EOF
sudo chmod 700 /usr/local/sbin/restore-openclaw
sudo restore-openclaw
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Simpan skrip itu: ia juga cara untuk undur selepas kemas kini yang bermasalah (langkah 11).

## 11. Kemas kini, dan undur bila perlu

Kemas kini bermakna menukar baris `image:` kepada tag dan digest yang lebih baharu, kemudian mencipta semula bekas.
Setiap kali bermula, imej menyemak folder keadaan dan memindahkannya ke format versi baharu bila perlu. Versi yang sudah
memindahkan keadaan tidak boleh ditukar begitu sahaja dengan versi lama: dalam ujian, 2026.10.6
tidak pernah membuka gateway atas keadaan yang ditulis oleh 2026.10.7, seperti amaran dokumentasi undur
OpenClaw sendiri. Jadi undur bermakna imej lama bersama backup yang dibuat sebelum kemas kini.

Oleh itu setiap kemas kini bermula dengan backup dari langkah 9. Arahan ini menjalankannya, kemudian mengemas kini ke
2026.10.7:

```bash
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Kalau versi baharu bermasalah, jalankan skrip pemulihan. Snapshot restic terkini ialah yang dibuat sejurus sebelum kemas
kini, jadi ia membawa balik fail Compose lama (dengan baris `image:` lama) dan keadaan lama:

```bash
sudo restore-openclaw
sudo docker exec -u node openclaw node dist/index.js --version
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Kemudian kemas kini semula dengan cara yang sama:

```bash
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Hantar satu lagi mesej kepada bot anda dari telefon, kemudian pastikan ejen menjawab selepas kemas kini:

```bash
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160
```

Untuk kemas kini sebenar, baca nota keluaran di halaman keluaran projek dahulu, kemudian ambil tag baharu dan digestnya
dari halaman imej di GitHub Container Registry.

## 12. Nyahpasang

Arahan ini menghentikan dan membuang bekas serta kedua-dua imej, mengeluarkan OpenClaw dari skrip backup, dan memadam
`/srv/openclaw` bersama semua perbualan dan ingatan, token gateway dan skrip pemulihan. Langkau baris `rm` kalau anda mahu menyimpan
data. Fail kunci dari bab 7 dan 8 serta snapshot restic kekal; buang secara berasingan kalau tidak diperlukan lagi.

```bash
cd /srv/openclaw
sudo docker compose down
sudo docker image rm ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
sudo sed -i -e '/^docker exec -u node openclaw /d' -e 's| /srv/openclaw/compose.yaml /srv/openclaw/backups$||' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
cd /
sudo rm -r /srv/openclaw /etc/agent/openclaw-gateway.token /usr/local/sbin/restore-openclaw
sudo docker ps -a
```

---

Tersekat pada satu langkah? Sasa Teguh Academy menjalankan sesi pemasangan berpandu: https://academy.sasateguh.com
