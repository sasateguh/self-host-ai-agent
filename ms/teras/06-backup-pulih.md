<!-- generated from kandungan/ms/teras/06-backup-pulih.md by alat/bina.py: edit the template, not this file -->
# 6. Backup yang sudah anda pulihkan

**Jawapan ringkas:** guna `restic` untuk mengambil backup data ejen yang disulitkan setiap malam, simpan satu salinan di
komputer anda sendiri, dan berlatih memulihkan sebelum anda memerlukannya. Backup yang tidak pernah dipulihkan hanyalah
tekaan. Langkah di bawah memadam data dengan sengaja, memulihkannya, dan membandingkan setiap fail dengan yang asal.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26.

Jalankan langkah ini sebagai pengguna dari bab 2. Langkah bertanda "di komputer anda" dijalankan dalam terminal di
mesin anda sendiri.

Bab ejen menyimpan data dalam folder masing-masing dan menambahnya ke backup. Di sini `/srv/agent-data` hanya memegang
beberapa fail ujian, jadi latihan pulih tidak boleh merosakkan apa-apa.

## 1. Cipta data ujian

Arahan terakhir merekod cincangan setiap fail, supaya hasil pulih boleh dibandingkan dengan yang asal kemudian.

```bash
sudo install -d -m 750 /srv/agent-data
echo "remember: the backup chapter was tested" | sudo tee /srv/agent-data/memory.txt >/dev/null
head -c 1048576 /dev/urandom | sudo tee /srv/agent-data/files.bin >/dev/null
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo tee /root/agent-data.sha256
```

## 2. Pasang restic

```bash
sudo apt-get update
sudo apt-get install -y restic
restic version
```

## 3. Cipta repositori backup

Repositori disulitkan dengan kata laluan rawak yang disimpan dalam `/root/restic-password`. **Tanpa kata laluan itu,
backup tidak boleh dibaca oleh sesiapa, termasuk anda.** Salin ke pengurus kata laluan anda sekarang:
`sudo cat /root/restic-password`.

Repositori dijadikan boleh dibaca oleh pengguna anda (`ejen`) supaya anda boleh menyalinnya ke
komputer anda tanpa root. Isinya disulitkan, jadi ini tidak mendedahkan data.

```bash
sudo install -d -m 750 -g ejen /var/backups/restic
sudo sh -c 'umask 077; openssl rand -base64 32 > /root/restic-password'
sudo restic init --repo /var/backups/restic --password-file /root/restic-password
sudo chgrp -R ejen /var/backups/restic
sudo chmod -R g+rX /var/backups/restic
sudo find /var/backups/restic -type d -exec chmod g+s {} +
```

## 4. Skrip backup

Skrip ini membuat backup folder itu, menyimpan 7 snapshot harian dan 4 mingguan, memadam yang lebih lama, dan menyemak
repositori. Untuk backup folder lain kelak, tambahkannya selepas `/srv/agent-data` pada baris `restic backup`.

```bash
sudo tee /usr/local/sbin/backup-agent >/dev/null <<'EOF'
#!/bin/sh
# Daily backup of the agent's data. Add more folders after /srv/agent-data.
set -eu
export RESTIC_REPOSITORY=/var/backups/restic
export RESTIC_PASSWORD_FILE=/root/restic-password
restic backup --quiet /srv/agent-data
restic forget --quiet --keep-daily 7 --keep-weekly 4 --prune
restic check --quiet
EOF
sudo chmod 700 /usr/local/sbin/backup-agent
```

## 5. Jalankan setiap malam

Pemasa systemd menjalankan skrip pada 03:30 waktu pelayan, ditambah lengah rawak sehingga 15 minit. `Persistent=true`
bermakna backup yang terlepas semasa pelayan mati dijalankan sebaik sahaja ia hidup semula.

```bash
sudo tee /etc/systemd/system/backup-agent.service >/dev/null <<'EOF'
[Unit]
Description=Back up the agent's data with restic

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/backup-agent
EOF
sudo tee /etc/systemd/system/backup-agent.timer >/dev/null <<'EOF'
[Unit]
Description=Daily backup of the agent's data

[Timer]
OnCalendar=*-*-* 03:30:00
RandomizedDelaySec=15m
Persistent=true

[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now backup-agent.timer
systemctl list-timers backup-agent.timer --no-pager
```

## 6. Ambil backup pertama sekarang

```bash
sudo systemctl start backup-agent.service
sudo restic snapshots --repo /var/backups/restic --password-file /root/restic-password
```

## 7. Salin backup keluar dari pelayan (di komputer anda)

Backup yang hanya ada di pelayan hilang bersama pelayan. Tarik satu salinan ke komputer anda sendiri. `rsync` hanya
memindahkan apa yang berubah, jadi menjalankannya semula kemudian adalah pantas. Jalankan selepas setiap backup yang
penting, atau secara berjadual di komputer anda.

```bash
rsync -a --delete ejen@203.0.113.10:/var/backups/restic/ agent-backup/
ls agent-backup
du -sh agent-backup
```

Untuk memulihkan dari salinan ini di mesin lain, pasang restic di situ dan halakan ke folder `agent-backup` dengan kata
laluan dari langkah 3.

## 8. Latihan pulih: padam data

Lakukan ini sekarang, semasa folder itu hanya memegang data ujian. Kelak, dengan data sebenar, berlatih dengan memulihkan
ke folder berasingan (`--target /tmp/restore-test`) dan membandingkannya.

```bash
sudo rm -r /srv/agent-data
ls /srv
```

## 9. Pulihkan dan bandingkan

`restic restore latest` mengembalikan snapshot terbaharu. Perbandingan tidak mencetak apa-apa jika setiap fail sama
dengan yang asal, kemudian baris terakhir mengesahkannya.

```bash
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target /
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo diff /root/agent-data.sha256 -
echo "restored files match the originals"
```

Ulang latihan ini setiap beberapa bulan, dan selepas sebarang perubahan pada skrip backup.
