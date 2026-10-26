<!-- generated from kandungan/ms/ejen/hermes-agent.md by alat/bina.py: edit the template, not this file -->
# Hermes Agent di pelayan anda

**Jawapan ringkas:** jalankan imej Docker rasmi Hermes Agent, dipin pada satu versi yang diuji, dengan Docker Compose.
Beri kunci API model dan token bot Telegram anda sebagai fail Compose `secrets` dari bab 7 dan 8, halakan ia ke
penyedia model serasi OpenAI, dan bercakap dengannya dari telefon melalui bot Telegram anda sendiri. Backup datanya
dengan arahan backup Hermes sendiri ditambah restic, dan kemas kini dengan menukar satu baris.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26, dengan Hermes Agent v0.22.5 (dikeluarkan
2026-10-23).

Hermes Agent ialah ejen AI sumber terbuka oleh Nous Research (lesen MIT, kod sumber di
https://github.com/NousResearch/hermes-agent, dokumentasi di https://hermes-agent.nousresearch.com/docs/). Ia menyimpan memori dan kemahiran
antara perbualan dan menjawab anda di platform sembang seperti Telegram. Bab ini mengikut dokumentasi Docker projek itu
sendiri untuk versi di atas.

Jalankan langkah ini sebagai pengguna dari bab 2, di pelayan yang sudah melalui bab 3 (firewall), 4 (Docker), 6 (backup),
7 (bot Telegram) dan 8 (kunci API model). Larian ujian memakai pengganti penyedia model dan pengganti API Telegram, kunci
rekaan, dan mesej ujian sebagai ganti mesej yang ditaip di telefon.

## 1. Muat turun versi yang diuji

Nama imej berakhir dengan tag (`v0.22.5`) dan digest (`sha256:...`). Tag ialah nama versi; digest
ialah cap jari imej tepat yang diuji, jadi Docker menolak imej lain walaupun seseorang memindahkan tag itu kemudian. Imej
ini kira-kira 1 GB untuk dimuat turun dan kira-kira 4 GB di cakera.

```bash
sudo docker pull nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d
sudo docker run --rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d --version 2>&1 | grep "^Hermes Agent"
```

## 2. Tulis fail tetapan

Hermes menyimpan semua yang dipelajarinya dalam satu folder data, di sini `/srv/hermes/data`. Fail tetapan memberitahunya
supaya memakai penyedia serasi OpenAI di `OPENAI_BASE_URL` (alamat yang sama seperti bab 8; tetapkan dahulu jika penyedia
anda memberi alamat lain) dan membaca kunci dari pemboleh ubah `MODEL_API_KEY`. Kunci itu sendiri tiada dalam fail ini.

Blok `if` hanya menambah baris bila alamat Telegram yang disimpan dalam bab 7 bukan alamat Telegram sendiri, contohnya
jika anda menjalankan pelayan Bot API tempatan. Dengan alamat biasa, ia tidak menambah apa-apa.

```bash
sudo install -d -m 700 /srv/hermes /srv/hermes/data
sudo tee /srv/hermes/data/config.yaml >/dev/null <<EOF
model:
  provider: custom
  base_url: ${OPENAI_BASE_URL:-https://api.openai.com/v1}
  key_env: MODEL_API_KEY
  default: MODEL_NAME
EOF
. <(sudo cat /etc/agent/telegram.env)
if [ "$TELEGRAM_API_URL" != https://api.telegram.org ]; then
  printf 'platforms:\n  telegram:\n    extra:\n      base_url: "%s/bot"\n      base_file_url: "%s/file/bot"\n' \
    "$TELEGRAM_API_URL" "$TELEGRAM_API_URL" | sudo tee -a /srv/hermes/data/config.yaml >/dev/null
fi
sudo cat /srv/hermes/data/config.yaml
```

## 3. Pilih model

Arahan ini menyenaraikan model yang boleh dipakai oleh kunci anda, kemudian menunggu anda menaip salah satu nama itu dan
menekan Enter.

```bash
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|^  default: .*|  default: $model|" /srv/hermes/data/config.yaml
```

## 4. Mulakan Hermes dengan Docker Compose

Fail Compose memberi bekas dua fail dari bab 7 dan 8 di bawah `/run/secrets/`. Baris `entrypoint` membaca kedua-duanya
ke dalam persekitaran proses ejen sahaja, kemudian memulakan imej seperti biasa, jadi kunci dan token tidak pernah muncul
dalam `docker inspect` (bab 8 menunjukkan mengapa itu penting). `TELEGRAM_ALLOWED_USERS` ditetapkan kepada ID sembang anda
dari bab 7: bot mengabaikan orang lain.

`network_mode: host` ialah apa yang dipakai fail Compose projek itu sendiri. Tiada port diterbitkan, jadi Docker tidak
menambah peraturan firewall sendiri (bab 4), dan firewall dari bab 3 masih terpakai pada apa-apa yang Hermes dengar.

```bash
sudo tee /srv/hermes/compose.yaml >/dev/null <<'EOF'
services:
  hermes:
    image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d
    container_name: hermes
    restart: unless-stopped
    # Same as the project's own compose file. Nothing is published: the gateway only makes outgoing connections.
    network_mode: host
    volumes:
      - ./data:/opt/data
    secrets:
      - model_key
      - telegram_env
    # Read the two secret files into the environment of the agent's processes only, then start the image as usual.
    entrypoint:
      - /bin/sh
      - -c
      - |
        export MODEL_API_KEY="$$(cat /run/secrets/model_key)"
        set -a; . /run/secrets/telegram_env; set +a
        export TELEGRAM_ALLOWED_USERS="$$TELEGRAM_CHAT_ID" TELEGRAM_HOME_CHANNEL="$$TELEGRAM_CHAT_ID"
        exec /opt/hermes/docker/entrypoint-dispatch.sh "$$@"
      - hermes
    command: ["gateway", "run"]
secrets:
  model_key:
    file: /etc/agent/model.key
  telegram_env:
    file: /etc/agent/telegram.env
EOF
cd /srv/hermes
sudo docker compose up -d
sudo docker compose ps
```

`restart: unless-stopped` memulakan Hermes semula selepas ranap atau but semula. Di dalam bekas, satu penyelia
memulakan semula ejen dalam beberapa saat jika ia berhenti.

## 5. Tunggu sambungan Telegram

Permulaan pertama mengambil masa satu atau dua minit sementara Hermes menyediakan folder datanya. Arahan ini menunggu
baris log yang menyatakan ia sudah bersambung ke Telegram.

```bash
cd /srv/hermes
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done
sudo docker compose ps --format '{{.Name}} {{.Status}}'
```

## 6. Hantar mesej pertama anda

Hantar apa-apa mesej kepada bot anda dari telefon. Arahan ini menunggu sehingga Hermes menghantar jawapannya, kemudian
memaparkan baris log untuk perbualan itu. Jawapannya sampai di Telegram.

```bash
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo grep -E "conversation turn|response ready" /srv/hermes/data/logs/agent.log | cut -c 1-160
```

## 7. Semak kunci dan token tidak bocor

Arahan ini menulis kunci dan token ke fail khas root buat seketika, mengira berapa baris dalam `docker inspect`, log bekas
dan fail dalam folder data yang mengandungi salah satu daripadanya, kemudian memadam fail itu. Ketiga-tiga kiraan mesti
sifar.

```bash
cd /srv/hermes
sudo sh -c 'umask 077; . /etc/agent/telegram.env; { printf "%s\n" "$TELEGRAM_BOT_TOKEN"; cat /etc/agent/model.key; echo; } > /root/secrets.txt'
inspect="$(sudo docker inspect hermes | sudo grep -c -F -f /root/secrets.txt || true)"
logs="$(sudo docker compose logs | sudo grep -c -F -f /root/secrets.txt || true)"
files="$(sudo grep -rlsF -D skip -f /root/secrets.txt data | wc -l || true)"
sudo rm /root/secrets.txt
echo "lines with the key or token: docker inspect $inspect, logs $logs, files in data/ $files"
test "$inspect $logs $files" = "0 0 0"
```

## 8. Semak tiada yang terbuka ke internet

Hermes bercakap dengan Telegram dan penyedia model anda melalui sambungan keluar, jadi ia tidak memerlukan port terbuka
atau alamat web. Ia mendengar pada dua port, iaitu API tempatannya dan satu port dalaman, dan kedua-duanya terikat pada
`127.0.0.1`:

```bash
sudo ss -ltnp | grep hermes
```

Jalankan ini di komputer anda sendiri untuk mengesahkan port API tidak boleh dicapai dari luar:

```bash
! nc -z -w 3 203.0.113.10 8642
echo "the agent's local API port is closed from outside"
```

Hermes tidak memerlukan laman Caddy dari bab 5. Hermes juga ada papan pemuka web pilihan dan pelayan API yang boleh
mengawal ejen dan membaca kuncinya. Kekalkan kedua-duanya pada `127.0.0.1` dan capai melalui terowong SSH; jangan
terbitkan pada port atau di belakang alamat web awam.

## 9. Tambah Hermes ke backup harian

Menyalin pangkalan data semasa ejen menulis kepadanya boleh menghasilkan salinan rosak. `hermes backup` membuat satu fail
zip yang konsisten bagi seluruh folder data, termasuk perbualan, memori, kemahiran dan tetapan. Arahan ini menambahnya ke
skrip backup harian dari bab 6, sebelum restic berjalan, dan membackup fail zip itu serta fail Compose. Kemudian ia
menjalankan backup sekali dan menyenaraikan apa yang disimpan restic.

```bash
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec hermes hermes backup --output /opt/data/backups/hermes.zip\n& /srv/hermes/compose.yaml /srv/hermes/data/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/hermes/
```

## 10. Berlatih memulihkan

Arahan ini memadam folder data, memulihkan fail zip dan fail Compose dengan restic, mengimport zip itu dengan
`hermes import` semasa ejen berhenti, dan memulakannya semula. Perbualan dari langkah 6 kembali dalam senarai sesi.
`</dev/null` menghalang bekas import sekali guna itu daripada membaca arahan yang anda tampal selepasnya.

```bash
cd /srv/hermes
sudo docker compose down
sudo rm -r /srv/hermes/data
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target / --include /srv/hermes
sudo docker compose run --rm hermes import /opt/data/backups/hermes.zip --force </dev/null 2>&1 | grep -v -e '^s6-rc' -e '^  + '
sudo docker compose up -d
sudo docker exec hermes hermes sessions list
```

## 11. Kemas kini, dan undur bila perlu

Mengemas kini bermaksud menukar baris `image:` kepada tag dan digest yang lebih baharu, kemudian mencipta bekas semula.
Folder data anda kekal, dan Hermes memindahkan fail tetapannya ke format baharu semasa bermula, sambil menyimpan salinan
yang lama dalam `data/backups/config/`. Jalankan backup dari langkah 9 sebelum mengemas kini.

Untuk berlatih kedua-dua arah, tukar ke keluaran sebelumnya (v0.22.4), iaitu apa yang anda
lakukan jika versi baharu bermasalah:

```bash
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d$|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"
```

Kemudian kemas kini kembali ke versi yang diuji:

```bash
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf$|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done
```

Hantar satu lagi mesej kepada bot anda dari telefon, kemudian semak ejen menjawab selepas kemas kini:

```bash
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo docker exec hermes hermes sessions list
```

Untuk kemas kini sebenar, baca nota keluaran di halaman keluaran projek dahulu, kemudian ambil tag baharu dan digestnya
dari halaman imej itu di Docker Hub.

## 12. Nyahpasang

Arahan ini menghentikan dan membuang bekas serta kedua-dua imej, mengeluarkan Hermes dari skrip backup, dan memadam
`/srv/hermes` bersama semua perbualan dan memori. Langkau baris `rm` jika anda mahu menyimpan data. Fail kunci dalam
`/etc/agent` dan snapshot restic kekal; buang secara berasingan jika anda tidak memerlukannya lagi.

```bash
cd /srv/hermes
sudo docker compose down
sudo docker image rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf
sudo sed -i -e '/^docker exec hermes hermes backup /d' -e 's| /srv/hermes/compose.yaml /srv/hermes/data/backups$||' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
cd /
sudo rm -r /srv/hermes
sudo docker ps -a
```

---

Tersekat pada satu langkah? Sasa Teguh Academy menjalankan sesi pemasangan berpandu: https://academy.sasateguh.com
