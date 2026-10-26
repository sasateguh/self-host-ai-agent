<!-- generated from kandungan/en/ejen/hermes-agent.md by alat/bina.py: edit the template, not this file -->
# Hermes Agent on your server

**Short answer:** run the official Hermes Agent Docker image, pinned to one tested version, with Docker Compose. Give it
your model API key and Telegram bot token as Compose secret files from chapters 7 and 8, point it at an
OpenAI-compatible model provider, and talk to it from your phone through your own Telegram bot. Back up its data with
its own backup command plus restic, and update by changing one line.

Tested on: `ubuntu:24.04` (VM), 2026-10-26, with Hermes Agent v0.22.5 (released
2026-10-23).

Hermes Agent is an open source AI agent by Nous Research (MIT licence, source at
https://github.com/NousResearch/hermes-agent, documentation at https://hermes-agent.nousresearch.com/docs/). It keeps a memory and skills
between conversations and answers you on chat platforms such as Telegram. This chapter follows the project's own Docker
documentation for the version above.

Run these steps as the user from chapter 2, on a server that has been through chapters 3 (firewall), 4 (Docker),
6 (backup), 7 (Telegram bot) and 8 (model API key). The test run used a stand-in model provider and a stand-in Telegram
API, made-up keys, and a test message in place of one typed on a phone.

## 1. Download the tested version

The image name ends with a tag (`v0.22.5`) and a digest (`sha256:...`). The tag is the version
name; the digest is a fingerprint of the exact image that was tested, so Docker refuses anything else, even if someone
moves the tag later. The image is about 1 GB to download and about 4 GB on disk.

```bash
sudo docker pull nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d
sudo docker run --rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d --version 2>&1 | grep "^Hermes Agent"
```

## 2. Write the settings file

Hermes keeps everything it learns in one data folder, here `/srv/hermes/data`. The settings file tells it to use an
OpenAI-compatible provider at `OPENAI_BASE_URL` (the same address as chapter 8; set it first if your provider gave you
one) and to read the key from the variable `MODEL_API_KEY`. The key itself is not in this file.

The `if` block only adds a line when the Telegram address saved in chapter 7 is not Telegram's own, for example if you
run a local Bot API server. With the normal address it adds nothing.

```bash
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
```

## 3. Choose the model

This lists the models your key can use, then waits for you to type one of the names and press Enter.

```bash
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[].id' | sort
read -rp "Type the model name to use, then press Enter: " model; sudo sed -i "s|^  default: .*|  default: $model|" /srv/hermes/data/config.yaml
```

## 4. Start Hermes with Docker Compose

The Compose file gives the container the two files from chapters 7 and 8 under `/run/secrets/`. The `entrypoint` lines
read them into the environment of the agent's own processes and then start the image as usual, so the key and token
never appear in `docker inspect` (chapter 8 shows why that matters). `TELEGRAM_ALLOWED_USERS` is set to your chat ID
from chapter 7: the bot ignores everyone else.

`network_mode: host` is what the project's own Compose file uses. No port is published, so Docker adds no firewall
rules of its own (chapter 4), and the firewall from chapter 3 still applies to anything Hermes listens on.

```bash
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
```

`restart: unless-stopped` starts Hermes again after a crash or a reboot. Inside the container, a supervisor restarts the
agent within seconds if it stops.

## 5. Wait for the Telegram connection

The first start takes a minute or two while Hermes prepares its data folder. This waits for the log line that says it
has connected to Telegram.

```bash
cd /srv/hermes
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done
sudo docker compose ps --format '{{.Name}} {{.Status}}'
```

## 6. Send your first message

Send any message to your bot from your phone. This command waits until Hermes has sent its answer, then shows the
log lines for the conversation. The answer arrives in Telegram.

```bash
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo grep -E "conversation turn|response ready" /srv/hermes/data/logs/agent.log | cut -c 1-160
```

## 7. Check the key and the token do not leak

This writes the key and the token to a root-only file for a moment, counts how many lines of `docker inspect`, the
container log and the files in the data folder contain either of them, then deletes the file. All three counts must be
zero.

```bash
cd /srv/hermes
sudo sh -c 'umask 077; . /etc/agent/telegram.env; { printf "%s\n" "$TELEGRAM_BOT_TOKEN"; cat /etc/agent/model.key; echo; } > /root/secrets.txt'
inspect="$(sudo docker inspect hermes | sudo grep -c -F -f /root/secrets.txt || true)"
logs="$(sudo docker compose logs | sudo grep -c -F -f /root/secrets.txt || true)"
files="$(sudo grep -rlsF -D skip -f /root/secrets.txt data | wc -l || true)"
sudo rm /root/secrets.txt
echo "lines with the key or token: docker inspect $inspect, logs $logs, files in data/ $files"
test "$inspect $logs $files" = "0 0 0"
```

## 8. Check nothing is open to the internet

Hermes talks to Telegram and to your model provider by making outgoing connections, so it needs no open port and no
web address. It does listen on two ports, its local API and one internal port, and both are bound to `127.0.0.1`:

```bash
sudo ss -ltnp | grep hermes
```

Run this on your own computer to confirm the API port cannot be reached from outside:

```bash
! nc -z -w 3 203.0.113.10 8642
echo "the agent's local API port is closed from outside"
```

You do not need the Caddy site from chapter 5 for Hermes. Hermes also has an optional web dashboard and an API server
that can control the agent and read its keys. Keep them on `127.0.0.1` and reach them through an SSH tunnel; do not
publish them on a port or behind a public web address.

## 9. Add Hermes to the daily backup

Copying a database while the agent writes to it can produce a broken copy. `hermes backup` makes a consistent zip file
of the whole data folder, including conversations, memory, skills and settings. This adds it to the daily backup script
from chapter 6, before restic runs, and backs up the zip and the Compose file. It then runs the backup once and lists
what restic stored.

```bash
sudo sed -i -e 's|^restic backup --quiet /srv/agent-data$|docker exec hermes hermes backup --output /opt/data/backups/hermes.zip\n& /srv/hermes/compose.yaml /srv/hermes/data/backups|' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
sudo systemctl start backup-agent.service
sudo restic ls latest --repo /var/backups/restic --password-file /root/restic-password | grep /srv/hermes/
```

## 10. Practise a restore

This deletes the data folder, restores the zip and the Compose file with restic, imports the zip with `hermes import`
while the agent is stopped, and starts it again. The conversation from step 6 is back in the session list. `</dev/null`
keeps the one-off import container from reading the commands you paste after it.

```bash
cd /srv/hermes
sudo docker compose down
sudo rm -r /srv/hermes/data
sudo restic restore latest --repo /var/backups/restic --password-file /root/restic-password --target / --include /srv/hermes
sudo docker compose run --rm hermes import /opt/data/backups/hermes.zip --force </dev/null 2>&1 | grep -v -e '^s6-rc' -e '^  + '
sudo docker compose up -d
sudo docker exec hermes hermes sessions list
```

## 11. Update, and go back if needed

Updating means changing the `image:` line to a newer tag and digest, then recreating the container. Your data folder
stays, and Hermes migrates its settings file on start, keeping a copy of the old one in `data/backups/config/`. Run the
backup from step 9 before you update.

To practise both directions, switch to the previous release (v0.22.4), which is what you
would do if a new version misbehaves:

```bash
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d$|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"
```

Then update back to the tested version:

```bash
cd /srv/hermes
sudo sed -i 's|image: nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf$|image: nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d|' compose.yaml
sudo docker compose up -d --quiet-pull
sudo docker exec hermes hermes --version | grep "^Hermes Agent"
until sudo docker compose logs | grep "Connected to Telegram"; do sleep 5; done
```

Send your bot another message from your phone, then check the agent answered after the update:

```bash
until sudo awk '/Starting Hermes Gateway/ {s = ""} /Sending response/ {s = $0} END {if (!s) exit 1; print s}' \
  /srv/hermes/data/logs/agent.log; do
  sleep 5
done
sudo docker exec hermes hermes sessions list
```

For a real update, read the release notes on the project's releases page first, then take the new tag and its digest
from the image's page on Docker Hub.

## 12. Uninstall

This stops and removes the container and both images, takes Hermes out of the backup script, and deletes `/srv/hermes`
with all conversations and memory. Skip the `rm` line if you want to keep the data. The key files in `/etc/agent` and
the restic snapshots stay; remove them separately if you no longer need them.

```bash
cd /srv/hermes
sudo docker compose down
sudo docker image rm nousresearch/hermes-agent:v0.22.5@sha256:9c5561579f3ffdf333401797094ac3a743738d6c25d40f4331c7bf77b694238d nousresearch/hermes-agent:v0.22.4@sha256:7a69201726bc64db2072a1371557137c23312d29705cda2b8ea2a0214a50a4cf
sudo sed -i -e '/^docker exec hermes hermes backup /d' -e 's| /srv/hermes/compose.yaml /srv/hermes/data/backups$||' /usr/local/sbin/backup-agent
sudo cat /usr/local/sbin/backup-agent
cd /
sudo rm -r /srv/hermes
sudo docker ps -a
```

---

Stuck on a step? Sasa Teguh Academy runs guided setup sessions: https://academy.sasateguh.com
