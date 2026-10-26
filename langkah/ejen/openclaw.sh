#!/usr/bin/env bash
# Bab ejen OpenClaw: imej Docker rasmi dipin (tag + digest, ejen/openclaw/ejen.toml), Docker Compose, kunci model + token
# bot sebagai fail rahsia Compose (bab 7, 8) yang dibaca OpenClaw sebagai SecretRef fail, penyedia serasi OpenAI,
# Telegram (senarai benar ID bab 7), satu mesej dijawab, backup (bab 6), undur + kemas kini versi, nyahpasang.
# Penyedia + Telegram = palsu (PRD K5): "pembaca" menaip mesej kepada bot (@mesej) dan ejen menjawab melalui penyedia
# palsu; jawapan direkod dalam bukti (palsu.dihantar).
# Jalankan: python3 alat/uji.py ejen/openclaw
# @perlu vm palsu besar
# @selepas teras/02-pengguna-ssh teras/03-firewall-kemas-kini teras/04-docker teras/06-backup-pulih teras/07-telegram teras/08-kunci-model

# @langkah tarik
sudo docker pull ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
sudo docker run --rm ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b node openclaw.mjs --version

# @langkah config
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

# @langkah model
# @tampal nama_model
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|MODEL_NAME|$model|g" /srv/openclaw/data/openclaw.json

# @langkah compose
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

# @langkah sedia
cd /srv/openclaw
if ! timeout 300 sh -c 'until curl -fsS http://127.0.0.1:18789/readyz >/dev/null 2>&1; do sleep 5; done'; then
  sudo docker compose ps -a --format '{{.Name}} {{.Status}}'
  sudo docker compose logs --no-log-prefix | grep -v -e '^[│◇├└┌ ]' -e '^$' | cut -c 1-200 | tail -n 15
  exit 1
fi
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done
sudo docker compose ps --format '{{.Name}} {{.Status}}'

# @langkah mesej
# @mesej Hello from the guide
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160
sudo docker stats --no-stream --format '{{.Name}} memory {{.MemUsage}}' openclaw

# @langkah semak-bocor
cd /srv/openclaw
sudo sh -c 'umask 077; . /etc/agent/telegram.env; { printf "%s\n" "$TELEGRAM_BOT_TOKEN"; cat /etc/agent/model.key; echo; cat /etc/agent/openclaw-gateway.token; } > /root/secrets.txt'
inspect="$(sudo docker inspect openclaw | sudo grep -c -F -f /root/secrets.txt || true)"
logs="$(sudo docker compose logs | sudo grep -c -F -f /root/secrets.txt || true)"
files="$(sudo grep -rlsF -D skip -f /root/secrets.txt data | wc -l || true)"
sudo rm /root/secrets.txt
echo "lines with the key or a token: docker inspect $inspect, logs $logs, files in data/ $files"
test "$inspect $logs $files" = "0 0 0"

# @langkah port
sudo ss -ltnp | grep ':18789 '

# @langkah port-luar luar
! nc -z -w 3 203.0.113.10 18789
echo "the agent's gateway port is closed from outside"

# @langkah backup
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec -u node openclaw sh -c "rm -f /home/node/backups/*.tar.gz \&\& node dist/index.js backup create --output /home/node/backups --verify >/dev/null"\n& /srv/openclaw/compose.yaml /srv/openclaw/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/openclaw/

# @langkah pulih
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

# @langkah kemas-kini
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done

# @langkah undur
sudo restore-openclaw
sudo docker exec -u node openclaw node dist/index.js --version
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done

# @langkah kemas-kini-semula
sudo systemctl start backup-agent.service
cd /srv/openclaw
sudo sed -i 's|image: ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b$|image: ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec -u node openclaw node dist/index.js --version
until sudo docker compose logs | grep "\[telegram\] .*starting provider"; do sleep 5; done

# @langkah mesej-selepas
# @mesej Still there after the update?
cd /srv/openclaw
until sudo docker compose logs | grep "\[telegram\] outbound send ok"; do sleep 5; done
sudo docker compose logs | grep -e "\[telegram\] Inbound message" | cut -c 1-160

# @langkah nyahpasang
cd /srv/openclaw
sudo docker compose down
sudo docker image rm ghcr.io/openclaw/openclaw:2026.10.7@sha256:fb26f0841659dc757f23feec9adeab51f11d76779a409db5d22e191b43841afa ghcr.io/openclaw/openclaw:2026.10.6@sha256:7dbff0fe5f5359b1badefe90a23efa9f203cd0d3c36bee095f4896c7a1d3864b
sudo sed -i -e '/^docker exec -u node openclaw /d' -e 's| /srv/openclaw/compose.yaml /srv/openclaw/backups$||' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
cd /
sudo rm -r /srv/openclaw /etc/agent/openclaw-gateway.token /usr/local/sbin/restore-openclaw
sudo docker ps -a
