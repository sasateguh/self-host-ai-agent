# 6. Backups you have actually restored

**Short answer:** use `restic` to take an encrypted backup of the agent's data every night, keep a copy on your own
computer, and practise a restore before you need one. A backup you have never restored is a guess. The steps below
delete the data on purpose, restore it, and compare every file with the original.

Tested on: {{diuji:teras/06-backup-pulih}}.

Run these steps as the user from chapter 2. Steps marked "on your computer" run in a terminal on your own machine.

The agent chapters keep their data in their own folders and add them to the backup. Here `/srv/agent-data` holds a few
test files, so the restore drill cannot hurt anything.

## 1. Create test data

The last command records a checksum of every file, so the restore can be compared with the original later.

{{langkah:teras/06-backup-pulih/data-contoh}}

## 2. Install restic

{{langkah:teras/06-backup-pulih/pasang-restic}}

## 3. Create the backup repository

The repository is encrypted with a random password stored in `/root/restic-password`. **Without that password the
backup cannot be read by anyone, including you.** Copy it into your password manager now:
`sudo cat /root/restic-password`.

The repository is made readable by your user (`{{config:contoh.pengguna}}`) so that you can copy it to your computer
without root. Its contents are encrypted, so this does not expose the data.

{{langkah:teras/06-backup-pulih/repositori}}

## 4. The backup script

The script backs up the folder, keeps 7 daily and 4 weekly snapshots, deletes older ones, and checks the repository.
To back up more folders later, add them after `/srv/agent-data` in the `restic backup` line.

{{langkah:teras/06-backup-pulih/skrip}}

## 5. Run it every night

A systemd timer runs the script at 03:30 server time, plus a random delay of up to 15 minutes. `Persistent=true` means a
backup missed while the server was off runs as soon as it starts again.

{{langkah:teras/06-backup-pulih/jadual}}

## 6. Take the first backup now

{{langkah:teras/06-backup-pulih/backup-pertama}}

## 7. Copy the backup off the server (on your computer)

A backup that lives only on the server disappears with the server. Pull a copy to your own computer. `rsync` only
transfers what changed, so running it again later is quick. Run it after each backup you care about, or on a schedule on
your computer.

{{langkah:teras/06-backup-pulih/salin-luar}}

To restore from this copy on another machine, install restic there and point it at the `agent-backup` folder with the
password from step 3.

## 8. Restore drill: delete the data

Do this now, while the folder only holds test data. Later, with real data, practise by restoring into a separate folder
instead (`--target /tmp/restore-test`) and comparing.

{{langkah:teras/06-backup-pulih/padam}}

## 9. Restore and compare

`restic restore latest` puts back the newest snapshot. The comparison prints nothing if every file is identical to the
original, then the last line confirms it.

{{langkah:teras/06-backup-pulih/pulih}}

Repeat the drill every few months, and after any change to the backup script.
