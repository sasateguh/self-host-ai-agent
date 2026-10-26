<!-- generated from kandungan/en/teras/09-pantau.md by alat/bina.py: edit the template, not this file -->
# 9. Monitoring and updates

**Short answer:** a small script checks the disk, memory, failed services, broken containers and pending reboots every
15 minutes, and sends you a Telegram message when that list changes, including "all clear" once a problem is gone.
Containers are updated by changing a pinned version tag, pulling and recreating; going back is the same steps with the
old tag. The steps below break a service on purpose to see the alert, then update and roll back a container.

Tested on: `ubuntu:24.04` (VM), 2026-10-26.

Run these steps as the user from chapter 2, on a server that has gone through chapter 3 (automatic security updates),
chapter 4 (Docker) and chapter 7 (Telegram bot). The test run sent its messages to a stand-in for the Telegram API.

## 1. The check script

The two limits at the top of the script are percentages; change them to suit your server. `check-server print` only
prints the current list and sends nothing.

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

The script remembers the last list it sent in `/var/lib/check-server/last`, so a problem that lasts all night gives you
one message, not one every 15 minutes.

## 2. Run it every 15 minutes

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

## 3. Try an alert

This starts a throwaway service that fails on purpose, then runs the check. A Telegram message lists
`check-demo.service` as failed, and the saved list shows the same.

```bash
sudo systemd-run --unit=check-demo --wait sh -c 'exit 3' || echo "check-demo failed on purpose"
sudo systemctl start check-server.service
sudo cat /var/lib/check-server/last
sudo grep check-demo /var/lib/check-server/last >/dev/null
```

## 4. Clear it

Telling systemd to forget the failed service makes the problem go away. The next check sends "all clear".

```bash
sudo systemctl reset-failed check-demo.service
sudo systemctl start check-server.service
sudo check-server print
test "$(sudo grep -c check-demo /var/lib/check-server/last)" = 0
```

When a real alert arrives, look at the service with `systemctl status <name>` and `journalctl -u <name> -n 50`.
For a container, use `sudo docker logs --tail 50 <name>`. For "a reboot is needed", run `sudo reboot` at a quiet time.

## 5. Pin container versions

Security updates for Ubuntu install themselves (chapter 3). Containers do not: they only change when you change them.
Write an exact version tag in `compose.yaml` (never `latest`), so you always know what is running and can go back. This
example runs an older Alpine release:

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

## 6. Update

Read the project's release notes first, then change the tag, pull the new image and recreate the container. The check
afterwards confirms nothing broke.

```bash
cd /srv/update-demo
sudo sed -i 's/alpine:3.19/alpine:3.20/' compose.yaml
sudo docker compose pull
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release
sudo check-server print
```

Take a backup (chapter 6) before updating anything that holds data.

## 7. Roll back

If the new version misbehaves, put the old tag back and recreate. The image is still on the server, so this works
without the internet.

```bash
cd /srv/update-demo
sudo sed -i 's/alpine:3.20/alpine:3.19/' compose.yaml
sudo docker compose up -d --wait
sudo docker compose exec -T app cat /etc/alpine-release
```

## 8. Clean up

Remove the example project and its images. The check script and its timer stay.

```bash
cd /srv/update-demo
sudo docker compose down
cd /
sudo rm -r /srv/update-demo
sudo docker image rm alpine:3.19 alpine:3.20
```
