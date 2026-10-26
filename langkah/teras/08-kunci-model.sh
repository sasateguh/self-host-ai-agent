#!/usr/bin/env bash
# Bab teras 8: kunci penyedia model. Ditampal ke fail root 0600, diuji tanpa kunci dalam senarai proses. DIUKUR: nilai -e
# kelihatan dalam `docker inspect`; kunci yang diberi sebagai fail rahsia Compose tidak kelihatan dalam inspect atau log.
# Putaran: kunci baharu + bekas dicipta semula (tanpa cipta semula, proses masih memegang kunci lama: langkah gagal).
# Penyedia = palsu (PRD K5); kunci ditampal dari [palsu.tampal] kunci_model (dua nilai berbeza).
# Jalankan: python3 alat/uji.py teras/08-kunci-model
# @perlu vm palsu
# @selepas teras/03-firewall-kemas-kini teras/04-docker

# @langkah alat
sudo apt-get update
sudo apt-get install -y curl jq

# @langkah simpan-kunci
# @tampal kunci_model
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/model.key
sudo bash -c 'read -rsp "Paste the API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'

# @langkah uji-kunci
sudo test -s /etc/agent/model.key
sudo stat -c '%a %U %n' /etc/agent/model.key
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'

# @langkah env-kelihatan
sudo docker run -d --name env-check -e OPENAI_API_KEY=example-not-a-real-key alpine:3.20 sleep 300 >/dev/null
sudo docker inspect env-check --format '{{json .Config.Env}}'
sudo docker inspect env-check | grep -c example-not-a-real-key
sudo docker rm -f env-check

# @langkah compose-rahsia
sudo install -d /srv/key-check
sudo tee /srv/key-check/compose.yaml >/dev/null <<'EOF'
services:
  key-check:
    image: alpine:3.20
    restart: unless-stopped
    # The key arrives as a file and is read into the environment of this process only.
    command: ["sh", "-c", "export OPENAI_API_KEY=\"$$(cat /run/secrets/model_key)\"; echo \"key loaded: $${#OPENAI_API_KEY} characters\"; exec sleep infinity"]
    secrets:
      - model_key
secrets:
  model_key:
    file: /etc/agent/model.key
EOF
cd /srv/key-check
sudo docker compose up -d --wait
sudo docker compose logs --no-log-prefix

# @langkah semak-bocor
cd /srv/key-check
id="$(sudo docker compose ps -q key-check)"
sudo docker inspect "$id" --format '{{json .Config.Env}}'
test "$(sudo docker inspect "$id" | sudo grep -c -F -f /etc/agent/model.key)" = 0
test "$(sudo docker compose logs | sudo grep -c -F -f /etc/agent/model.key)" = 0
echo "the key is not in docker inspect or in the logs"

# @langkah putar
# @tampal kunci_model
sudo bash -c 'read -rsp "Paste the NEW API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'

# @langkah guna-kunci-baharu
cd /srv/key-check
sudo docker compose up -d --wait --force-recreate
sudo docker compose logs --no-log-prefix
test "$(sudo docker compose logs --no-log-prefix | tail -n 1)" = "key loaded: $(sudo stat -c %s /etc/agent/model.key) characters"
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'

# @langkah kemas
cd /srv/key-check
sudo docker compose down
cd /
sudo rm -r /srv/key-check
sudo docker image rm alpine:3.20
