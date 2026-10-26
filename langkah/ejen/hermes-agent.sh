#!/usr/bin/env bash
# Bab ejen Hermes Agent: imej Docker rasmi dipin (tag + digest, ejen/hermes-agent/ejen.toml), Docker Compose, kunci model +
# token bot sebagai fail rahsia Compose (bab 7, 8), penyedia serasi OpenAI, Telegram, satu mesej dijawab, backup (bab 6),
# undur + kemas kini versi, nyahpasang. Penyedia + Telegram = palsu (PRD K5): "pembaca" menaip mesej kepada bot (@mesej)
# dan ejen menjawab melalui penyedia palsu; jawapan direkod dalam bukti (palsu.dihantar).
# Jalankan: python3 alat/uji.py ejen/hermes-agent
# @perlu vm palsu besar
# @selepas teras/02-pengguna-ssh teras/03-firewall-kemas-kini teras/04-docker teras/06-backup-pulih teras/07-telegram teras/08-kunci-model

# @langkah tarik
sudo docker pull nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d
sudo docker run --rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d --version 2>&1 | grep "^Hermes Agent"

# @langkah config
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

# @langkah model
# @tampal nama_model
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|^  default: .*|  default: $model|" /srv/hermes/data/config.yaml

# @langkah compose
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

# @langkah sedia
cd /srv/hermes
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done
sudo docker compose ps --format '{{.Name}} {{.Status}}'

# @langkah mesej
# @mesej Hello from the guide
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo grep -E "conversation turn|response ready" /srv/hermes/data/logs/agent.log | cut -c 1-160

# @langkah semak-bocor
cd /srv/hermes
sudo sh -c 'umask 077; . /etc/agent/telegram.env; { printf "%s\n" "$TELEGRAM_BOT_TOKEN"; cat /etc/agent/model.key; echo; } > /root/secrets.txt'
inspect="$(sudo docker inspect hermes | sudo grep -c -F -f /root/secrets.txt || true)"
logs="$(sudo docker compose logs | sudo grep -c -F -f /root/secrets.txt || true)"
files="$(sudo grep -rlsF -D skip -f /root/secrets.txt data | wc -l || true)"
sudo rm /root/secrets.txt
echo "lines with the key or token: docker inspect $inspect, logs $logs, files in data/ $files"
test "$inspect $logs $files" = "0 0 0"

# @langkah port
sudo ss -ltnp | grep hermes

# @langkah port-luar luar
! nc -z -w 3 203.0.113.10 8642
echo "the agent's local API port is closed from outside"

# @langkah backup
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec hermes hermes backup --output /opt/data/backups/hermes.zip\n& /srv/hermes/compose.yaml /srv/hermes/data/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/hermes/

# @langkah pulih
cd /srv/hermes
sudo docker compose down
sudo rm -r /srv/hermes/data
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target / --include /srv/hermes
sudo docker compose run --rm hermes import /opt/data/backups/hermes.zip --force </dev/null 2>&1 | grep -v -e '^s6-rc' -e '^  + '
sudo docker compose up -d
sudo docker exec hermes hermes sessions list

# @langkah undur
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d$|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"

# @langkah kemas-kini
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf$|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done

# @langkah mesej-selepas
# @mesej Still there after the update?
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo docker exec hermes hermes sessions list

# @langkah nyahpasang
cd /srv/hermes
sudo docker compose down
sudo docker image rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf
sudo sed -i -e '/^docker exec hermes hermes backup /d' -e 's| /srv/hermes/compose.yaml /srv/hermes/data/backups$||' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
cd /
sudo rm -r /srv/hermes
sudo docker ps -a
