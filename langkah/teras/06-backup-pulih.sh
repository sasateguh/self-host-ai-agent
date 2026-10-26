#!/usr/bin/env bash
# Bab teras 6: backup harian restic (disulitkan, berjadual systemd), salinan ditarik ke komputer anda, latihan PULIH
# (padam -> pulih -> banding cincangan). Pelayan sudah melalui bab 2 (pengguna ejen, SSH kunci sahaja).
# Jalankan: python3 alat/uji.py teras/06-backup-pulih
# @perlu vm
# @selepas teras/02-pengguna-ssh

# @langkah data-contoh
sudo install -d -m 750 /srv/agent-data
echo "remember: the backup chapter was tested" | sudo tee /srv/agent-data/memory.txt >/dev/null
head -c 1048576 /dev/urandom | sudo tee /srv/agent-data/files.bin >/dev/null
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo tee /root/agent-data.sha256

# @langkah pasang-restic
sudo apt-get update
sudo apt-get install -y restic
restic version

# @langkah repositori
sudo install -d -m 750 -g ejen /var/backups/restic
sudo sh -c 'umask 077; openssl rand -base64 32 > /root/restic-password'
sudo restic init --repo /var/backups/restic --password-file /root/restic-password
sudo chgrp -R ejen /var/backups/restic
sudo chmod -R g+rX /var/backups/restic
sudo find /var/backups/restic -type d -exec chmod g+s {} +

# @langkah skrip
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

# @langkah jadual
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

# @langkah backup-pertama
sudo systemctl start backup-agent.service
sudo restic snapshots --repo /var/backups/restic --password-file /root/restic-password

# @langkah salin-luar luar
rsync -a --delete ejen@203.0.113.10:/var/backups/restic/ agent-backup/
ls agent-backup
du -sh agent-backup

# @langkah padam
sudo rm -r /srv/agent-data
ls /srv

# @langkah pulih
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target /
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo diff /root/agent-data.sha256 -
echo "restored files match the originals"
