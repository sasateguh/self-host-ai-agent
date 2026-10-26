<!-- generated from kandungan/en/teras/06-backup-pulih.md by alat/bina.py: edit the template, not this file -->
# 6. Backups you have actually restored

**Short answer:** use `restic` to take an encrypted backup of the agent's data every night, keep a copy on your own
computer, and practise a restore before you need one. A backup you have never restored is a guess. The steps below
delete the data on purpose, restore it, and compare every file with the original.

Tested on: `ubuntu:24.04` (VM), 2026-10-26.

Run these steps as the user from chapter 2. Steps marked "on your computer" run in a terminal on your own machine.

The agent chapters keep their data in their own folders and add them to the backup. Here `/srv/agent-data` holds a few
test files, so the restore drill cannot hurt anything.

## 1. Create test data

The last command records a checksum of every file, so the restore can be compared with the original later.

```bash
sudo install -d -m 750 /srv/agent-data
echo "remember: the backup chapter was tested" | sudo tee /srv/agent-data/memory.txt >/dev/null
head -c 1048576 /dev/urandom | sudo tee /srv/agent-data/files.bin >/dev/null
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo tee /root/agent-data.sha256
```

## 2. Install restic

```bash
sudo apt-get update
sudo apt-get install -y restic
restic version
```

## 3. Create the backup repository

The repository is encrypted with a random password stored in `/root/restic-password`. **Without that password the
backup cannot be read by anyone, including you.** Copy it into your password manager now:
`sudo cat /root/restic-password`.

The repository is made readable by your user (`ejen`) so that you can copy it to your computer
without root. Its contents are encrypted, so this does not expose the data.

```bash
sudo install -d -m 750 -g ejen /var/backups/restic
sudo sh -c 'umask 077; openssl rand -base64 32 > /root/restic-password'
sudo restic init --repo /var/backups/restic --password-file /root/restic-password
sudo chgrp -R ejen /var/backups/restic
sudo chmod -R g+rX /var/backups/restic
sudo find /var/backups/restic -type d -exec chmod g+s {} +
```

## 4. The backup script

The script backs up the folder, keeps 7 daily and 4 weekly snapshots, deletes older ones, and checks the repository.
To back up more folders later, add them after `/srv/agent-data` in the `restic backup` line.

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

## 5. Run it every night

A systemd timer runs the script at 03:30 server time, plus a random delay of up to 15 minutes. `Persistent=true` means a
backup missed while the server was off runs as soon as it starts again.

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

## 6. Take the first backup now

```bash
sudo systemctl start backup-agent.service
sudo restic snapshots --repo /var/backups/restic --password-file /root/restic-password
```

## 7. Copy the backup off the server (on your computer)

A backup that lives only on the server disappears with the server. Pull a copy to your own computer. `rsync` only
transfers what changed, so running it again later is quick. Run it after each backup you care about, or on a schedule on
your computer.

```bash
rsync -a --delete ejen@203.0.113.10:/var/backups/restic/ agent-backup/
ls agent-backup
du -sh agent-backup
```

To restore from this copy on another machine, install restic there and point it at the `agent-backup` folder with the
password from step 3.

## 8. Restore drill: delete the data

Do this now, while the folder only holds test data. Later, with real data, practise by restoring into a separate folder
instead (`--target /tmp/restore-test`) and comparing.

```bash
sudo rm -r /srv/agent-data
ls /srv
```

## 9. Restore and compare

`restic restore latest` puts back the newest snapshot. The comparison prints nothing if every file is identical to the
original, then the last line confirms it.

```bash
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target /
sudo find /srv/agent-data -type f -exec sha256sum {} + | sort -k 2 | sudo diff /root/agent-data.sha256 -
echo "restored files match the originals"
```

Repeat the drill every few months, and after any change to the backup script.
