<!-- generated from kandungan/en/teras/08-kunci-model.md by alat/bina.py: edit the template, not this file -->
# 8. Keeping the model API key out of sight

**Short answer:** paste the API key from your model provider into a root-only file, and give it to containers as a
Compose secret (a file mounted at `/run/secrets/`), not as an environment variable on the command line or in
`compose.yaml`. An environment variable set with `-e` or `environment:` is visible to anyone who can run
`docker inspect`. The steps below show that, then check that the secret file approach keeps the key out of
`docker inspect` and the logs, and rotate the key.

Tested on: `ubuntu:24.04` (VM), 2026-10-26.

Run these steps as the user from chapter 2, on a server with Docker from chapter 4. The test run used a stand-in model
provider and made-up keys.

## 1. Get a key

Create an API key in your model provider's dashboard. Most providers let you limit a key: give it a spending limit and,
if offered, access to the models the agent needs only. Use one key per server so you can revoke it without breaking
anything else.

## 2. Install the tools

```bash
sudo apt-get update
sudo apt-get install -y curl jq
```

## 3. Store the key in a root-only file

The last command waits for you to paste the key and press Enter. It does not show the key and does not put it in your
shell history.

```bash
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/model.key
sudo bash -c 'read -rsp "Paste the API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'
```

## 4. Check the key works

This lists the models the key can use. The key is passed to `curl` through its standard input, so it never appears in
the process list. `OPENAI_BASE_URL` is the address of an OpenAI-compatible API; if your provider gives you a different
address, set it first, for example `export OPENAI_BASE_URL=https://your-provider.example/v1`.

```bash
sudo test -s /etc/agent/model.key
sudo stat -c '%a %U %n' /etc/agent/model.key
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'
```

## 5. See the problem: environment variables are visible

Many agent instructions say `docker run -e OPENAI_API_KEY=...`. This starts a container that way with a fake key and
shows where it ends up. The count on the last line is the number of lines in the `docker inspect` output that contain the
key:

```bash
sudo docker run -d --name env-check -e OPENAI_API_KEY=example-not-a-real-key alpine:3.20 sleep 300 >/dev/null
sudo docker inspect env-check --format '{{json .Config.Env}}'
sudo docker inspect env-check | grep -c example-not-a-real-key
sudo docker rm -f env-check
```

The same applies to `environment:` in `compose.yaml`, and to the file itself if you commit it to git.

## 6. Give the key to the container as a file

Compose mounts the key file at `/run/secrets/model_key` inside the container. The container's command reads it into the
environment of its own process only. The example prints the length of the key, never the key.

```bash
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
```

The agent chapters use the same `secrets:` block. Some agents read the file directly (look for a setting ending in
`_FILE`); others need the one-line `export` shown here.

## 7. Check the key does not leak

These commands search the full `docker inspect` output and the container logs for the key itself. Both counts must be
zero.

```bash
cd /srv/key-check
id="$(sudo docker compose ps -q key-check)"
sudo docker inspect "$id" --format '{{json .Config.Env}}'
test "$(sudo docker inspect "$id" | sudo grep -c -F -f /etc/agent/model.key)" = 0
test "$(sudo docker compose logs | sudo grep -c -F -f /etc/agent/model.key)" = 0
echo "the key is not in docker inspect or in the logs"
```

## 8. Rotate the key

Rotate when someone who had access leaves, when the key may have leaked, or on a schedule. Create a new key at the
provider first, then paste it here.

```bash
sudo bash -c 'read -rsp "Paste the NEW API key, then press Enter: " k; echo; printf "%s" "$k" > /etc/agent/model.key'
```

A running container keeps the old key until it is created again. `--force-recreate` does that; the log line shows the
new key's length, and the model list proves the new key works.

```bash
cd /srv/key-check
sudo docker compose up -d --wait --force-recreate
sudo docker compose logs --no-log-prefix
test "$(sudo docker compose logs --no-log-prefix | tail -n 1)" = "key loaded: $(sudo stat -c %s /etc/agent/model.key) characters"
sudo sh -c 'printf "header = \"Authorization: Bearer %s\"\n" "$(cat /etc/agent/model.key)"' \
  | curl -fsS -K - "${OPENAI_BASE_URL:-https://api.openai.com/v1}/models" | jq -r '.data[:5][].id'
```

Now revoke the old key in the provider's dashboard.

## 9. Clean up

Remove the test project and image. The key file stays for the agent chapters.

```bash
cd /srv/key-check
sudo docker compose down
cd /
sudo rm -r /srv/key-check
sudo docker image rm alpine:3.20
```
