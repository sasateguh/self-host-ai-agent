<!-- generated from kandungan/en/ejen/openclaw.md by alat/bina.py: edit the template, not this file -->
# OpenClaw on your server

**Short answer:** run the official OpenClaw Docker image, pinned to one tested version, with Docker Compose. OpenClaw
reads your model API key, your Telegram bot token and its own gateway token from files (chapters 7 and 8), talks to an
OpenAI-compatible model provider, and answers only your own Telegram account. Back it up with its own backup command
plus restic, and update by changing one line.

Tested on: `ubuntu:24.04` (VM), 2026-10-26, with OpenClaw v2026.10.7 (released
2026-10-24).

OpenClaw is an open source personal AI assistant (MIT licence, source at
https://github.com/openclaw/openclaw, documentation at https://docs.openclaw.ai/). A long-running process called the
gateway connects it to chat apps such as Telegram and to your model provider. This chapter follows the project's own
Docker, Telegram, provider, secrets and backup documentation for the version above.

Run these steps as the user from chapter 2, on a server that has been through chapters 3 (firewall), 4 (Docker),
6 (backup), 7 (Telegram bot) and 8 (model API key). The test run used a stand-in model provider and a stand-in Telegram
API, made-up keys, and a test message in place of one typed on a phone.

Plan for a server with at least 4 GB of memory. In the test the OpenClaw container used about 2 GB after its first
answer, and on a test machine with 2 GB in total every command took minutes.

## 1. Download the previous release first

The image name ends with a tag and a digest (`sha256:...`). The tag is the version name; the digest is a fingerprint of
the exact image that was tested, so Docker refuses anything else, even if someone moves the tag later. The images come
from the GitHub Container Registry, which the project uses for its releases. Each is about 700 MB to download.

This chapter starts on the release before the tested one, 2026.10.6, so that step 11 is a real
update to 2026.10.7 and a real rollback. You finish on 2026.10.7. If you would rather
start on the tested version, use its tag and digest from step 11 in steps 1 and 4.

```bash
sudo docker pull ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
sudo docker run --rm ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b node openclaw.mjs --version
```

## 2. Write the settings file

OpenClaw keeps its settings, conversations and memory in one state folder, here `/srv/openclaw/data`. The container runs
as a user with ID 1000, so the folder belongs to that ID. A second folder, `/srv/openclaw/backups`, will hold backup
archives (step 9).

The first lines create a gateway token: a random password that protects the gateway's control interface, kept next to
the key from chapter 8 and readable by root only.

The settings file then says:

- `gateway`: listen on `127.0.0.1` only, and require the gateway token.
- `secrets.providers`: two files that hold a single value each, the model key and the gateway token. The settings file
  points at them and never contains the values.
- `models`: an OpenAI-compatible provider at `OPENAI_BASE_URL` (the same address as chapter 8; set it first if your
  provider gave you one), with the key from the file.
- `channels.telegram`: read the bot token from a file, and with `dmPolicy: "allowlist"` answer only the chat ID saved in
  chapter 7. Anyone else who finds the bot gets nothing.

OpenClaw refuses to connect to addresses inside a private network by default, as a guard against requests being
redirected to your own machines. The two `if` checks only relax that when you use one: a model address that starts with
`http://` (for example a model server on your own network) or a Telegram address that is not Telegram's own (a local
Bot API server). With a normal provider and Telegram they add nothing.

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

## 3. Choose the model

This lists the models your key can use, then waits for you to type one of the names and press Enter.

```bash
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|MODEL_NAME|$model|g" /srv/openclaw/data/openclaw.json
```

## 4. Start OpenClaw with Docker Compose

The Compose file gives the container the files from chapters 7 and 8 and the gateway token under `/run/secrets/`. Those
copies belong to root, like the originals, and OpenClaw runs as an ordinary user, so the container starts as root for a
moment: the `entrypoint` lines copy the three values into a memory-only folder (`tmpfs`) that only OpenClaw's user can
read, make sure the state and backup folders belong to that user, then switch to it with `setpriv` and start the image
as usual. The image's health check runs through `setpriv` too, so nothing in the state folder is ever created by root.
For the same reason, every `docker exec` in this chapter uses `-u node`. Nothing is written to disk, and the values
never appear in `docker inspect` (chapter 8 shows why that matters).

`network_mode: host` with the gateway bound to `127.0.0.1` means no port is published, so Docker adds no firewall rules
of its own (chapter 4). `cap_drop` and `no-new-privileges` come from the project's own Compose file.

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

`restart: unless-stopped` starts OpenClaw again after a crash or a reboot.

## 5. Wait for the Telegram connection

The first start takes a minute or two: OpenClaw checks and prepares its state folder before the gateway opens. This
waits for the gateway's readiness check, then for the log line that says the Telegram connection has started. If the
gateway is not ready after five minutes, it shows the container status and the last log lines without their decoration,
which usually name the problem.

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

## 6. Send your first message

Send any message to your bot from your phone. This command waits for the log line that says OpenClaw has sent its
answer, then shows the line for your incoming message. The answer arrives in Telegram.

OpenClaw also runs periodic background checks and may send you a short first note about them; the note says which
setting turns them off. The test run received that note too.

```bash
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160
sudo docker stats --no-stream --format '{{.Name}} memory {{.MemUsage}}' openclaw
```

## 7. Check the keys and tokens do not leak

This writes the model key, the bot token and the gateway token to a root-only file for a moment, counts how many lines
of `docker inspect`, the container log and the files in the state folder contain any of them, then deletes the file.
All three counts must be zero.

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

## 8. Check nothing is open to the internet

OpenClaw talks to Telegram and to your model provider by making outgoing connections, so it needs no open port and no
web address. The gateway listens on port 18789, bound to `127.0.0.1`:

```bash
sudo ss -ltnp | grep ':18789 '
```

Run this on your own computer to confirm the port cannot be reached from outside:

```bash
! nc -z -w 3 203.0.113.10 18789
echo "the agent's gateway port is closed from outside"
```

You do not need the Caddy site from chapter 5 for OpenClaw. The gateway also serves a web control panel that can change
settings and run commands. Keep it on `127.0.0.1` and reach it through an SSH tunnel with the gateway token; do not
publish it on a port or behind a public web address.

## 9. Add OpenClaw to the daily backup

Copying a database while the agent writes to it can produce a broken copy. `openclaw backup create` makes a consistent
archive of the state folder, checks it with `--verify`, and does not write the values of keys into it. This adds
it to the daily backup script from chapter 6, before restic runs: it deletes yesterday's archive, writes a new one, and
restic stores the archive and the Compose file. It then runs the backup once and lists what restic stored.

```bash
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec -u node openclaw sh -c "rm -f /home/node/backups/*.tar.gz \&\& node dist/index.js backup create --output /home/node/backups --verify >/dev/null"\n& /srv/openclaw/compose.yaml /srv/openclaw/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/openclaw/
```

If another agent from this guide already changed the `restic backup` line, add the two lines by hand instead.

## 10. Practise a restore

This writes a small restore script, `/usr/local/sbin/restore-openclaw`, and runs it. The script stops OpenClaw, deletes
the state folder, the archive and the Compose file, gets the archive and the Compose file back from restic, and unpacks
the archive with `openclaw backup restore` into an empty folder. OpenClaw never restores over live data, so the script
then copies the restored state folder into place. Before starting the gateway again, a one-off container lists the
conversations in the restored folder: the one from step 6 is back. `</dev/null` keeps the one-off containers from
reading the commands you paste after them.

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

Keep the script: it is also how you go back after an update that went wrong (step 11).

## 11. Update, and go back if needed

Updating means changing the `image:` line to a newer tag and digest, then recreating the container. On each start the
image checks the state folder and migrates it to the new version's format if needed. A version that has already
migrated the state cannot simply be swapped for the older one: in the test, 2026.10.6 never
opened its gateway on state that 2026.10.7 had written, as OpenClaw's own rollback documentation warns.
Going back therefore means the older image together with a backup made before the update.

So every update starts with the backup from step 9. This runs it, then updates to 2026.10.7:

```bash
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

If the new version misbehaves, run the restore script. The latest restic snapshot is the one made just before the
update, so it brings back both the old Compose file (with the old `image:` line) and the old state:

```bash
sudo restore-openclaw
sudo docker exec -u node openclaw node dist/index.js --version
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Then update again, the same way:

```bash
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
```

Send your bot another message from your phone, then check the agent answered after the update:

```bash
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160
```

For a real update, read the release notes on the project's releases page first, then take the new tag and its digest
from the image's page on the GitHub Container Registry.

## 12. Uninstall

This stops and removes the container and both images, takes OpenClaw out of the backup script, and deletes
`/srv/openclaw` with all conversations and memory, the gateway token and the restore script. Skip the `rm` line if you want to keep the
data. The key files from chapters 7 and 8 and the restic snapshots stay; remove them separately if you no longer need
them.

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

Stuck on a step? Sasa Teguh Academy runs guided setup sessions: https://academy.sasateguh.com
