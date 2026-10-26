#!/usr/bin/env bash
# Templat bab ejen: salin ke langkah/ejen/<nama>.sh (CONTRIBUTING.md). Ganti `pemilik/projek:v1.2.3@sha256:...` dengan
# [imej] dan [imej_undur] ejen/<nama>/ejen.toml (tepat tag@digest), dan `ejen-contoh` dengan nama ejen.
# Setiap blok = satu skrip `bash -c` di bawah `set -euo pipefail`. Penyedia model + Telegram = palsu semasa ujian.
# Jalankan: python3 alat/uji.py ejen/<nama>
# @perlu vm palsu besar
# @selepas teras/02-pengguna-ssh teras/03-firewall-kemas-kini teras/04-docker teras/06-backup-pulih teras/07-telegram teras/08-kunci-model

# @langkah tarik
sudo docker pull pemilik/projek:v1.2.3@sha256:0000000000000000000000000000000000000000000000000000000000000000

# @langkah config
# Folder data /srv/ejen-contoh (700). Fail tetapan TIDAK menyimpan kunci model atau token bot: ejen membacanya daripada
# fail rahsia Compose /etc/agent/model.key + /etc/agent/telegram.env (bab 7, 8). Hanya ID sembang bab 7 dijawab.
sudo install -d -m 700 /srv/ejen-contoh /srv/ejen-contoh/data

# @langkah model
# @tampal nama_model
# Senaraikan model kunci itu, kemudian pembaca menaip satu nama (read).
read -rp "Type the model name to use, then press Enter: " model; echo "$model"

# @langkah compose
# compose.yaml: image dipin, restart: unless-stopped, tiada `ports:`, secrets: model_key + telegram_env.
cd /srv/ejen-contoh

# @langkah sedia
# Tunggu ejen bersambung ke Telegram (baris log atau titik semakan kesihatan).
true

# @langkah mesej
# @mesej Hello from the guide
# Tunggu sehingga ejen menghantar jawapan, kemudian tunjukkan buktinya (log atau senarai sesi).
true

# @langkah semak-bocor
# Kira baris yang membawa kunci/token dalam `docker inspect`, log bekas dan fail data: mesti 0 0 0.
true

# @langkah port-luar luar
! nc -z -w 3 203.0.113.10 8080

# @langkah backup
# Alat backup ejen sendiri (salinan konsisten) dalam /usr/local/sbin/backup-agent sebelum restic (bab 6).
true

# @langkah pulih
# Padam folder data, `restic restore`, pulihkan, mulakan semula, perbualan langkah mesej kembali.
true

# @langkah undur
# Tukar baris image: ke [imej_undur], `docker compose up -d`, semak versi.
true

# @langkah kemas-kini
# Tukar semula ke [imej], semak versi, tunggu Telegram.
true

# @langkah nyahpasang
# compose down, buang imej, keluarkan dari backup-agent, padam /srv/ejen-contoh.
true
