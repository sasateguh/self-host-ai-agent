<!-- generated from kandungan/en/teras/07-telegram.md by alat/bina.py: edit the template, not this file -->
# 7. A Telegram bot for your server

**Short answer:** create a bot with Telegram's @BotFather, paste its token into a file only root can read, send the bot
one message from your phone, then look up your chat ID and send a test message back. The agent chapters and the
monitoring in chapter 9 use this bot and this file.

Tested on: `ubuntu:24.04` (VM), 2026-10-26.

Run these steps as the user from chapter 2. The test run talks to a stand-in for the Telegram API, so no real bot was
used.

## 1. Create the bot (on your phone)

1. In Telegram, open a chat with **@BotFather** (check for the blue verified tick; copies exist).
2. Send `/newbot`, then a display name, then a username that ends in `bot`.
3. BotFather replies with a token that looks like `123456789:AA...`. Anyone holding it controls the bot. Do not paste it
   into a chat, a screenshot or a file you commit.
4. Open a chat with your new bot and send it any message, for example `/start`. A bot cannot write to you first, and
   step 4 below finds your chat ID from this message.

## 2. Install the tools

```bash
sudo apt-get update
sudo apt-get install -y curl jq
```

## 3. Store the token in a root-only file

The commands create `/etc/agent`, readable by root only, and a file inside it with mode `600`. The last command waits for
you to paste the token and press Enter. It reads the token without showing it, so it never appears on screen, in your
shell history, or in the list of running processes. `TELEGRAM_API_URL` is the address of the Telegram API; leave it as
it is.

```bash
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/telegram.env
echo "TELEGRAM_API_URL=${TELEGRAM_API_URL:-https://api.telegram.org}" | sudo tee /etc/agent/telegram.env >/dev/null
sudo bash -c 'read -rsp "Paste the bot token, then press Enter: " t; echo; echo "TELEGRAM_BOT_TOKEN=$t" >> /etc/agent/telegram.env'
```

## 4. Check the token

This asks Telegram who the bot is and prints its username. The token is passed to `curl` through its standard input,
not on the command line, so other users on the server cannot see it in the process list.

```bash
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/getMe"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K - | jq -r '.result.username'
```

If you see `401 Unauthorized`, the token was pasted wrong. Run step 3 again.

## 5. Find your chat ID

The bot lists the messages waiting for it. You should see your `/start` message with a number in front: that number is
your chat ID. The last line saves it to the same file.

```bash
. <(sudo cat /etc/agent/telegram.env)
updates="$(printf 'url = "%s/bot%s/getUpdates"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K -)"
jq -r '.result[].message | "\(.chat.id) \(.from.first_name): \(.text)"' <<<"$updates"
chat_id="$(jq -er '.result[-1].message.chat.id' <<<"$updates")"
echo "TELEGRAM_CHAT_ID=$chat_id" | sudo tee -a /etc/agent/telegram.env >/dev/null
```

If the list is empty, send the bot another message from your phone and run this step again.

## 6. Send a test message

The message arrives on your phone and the command prints its text.

```bash
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/sendMessage"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" \
  | curl -fsS -K - -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="Hello from your server" \
  | jq -r '.result.text'
```

## 7. Check the file

The file must be mode `600` and owned by root. The last command shows the setting names with the values hidden.

```bash
sudo stat -c '%a %U %n' /etc/agent /etc/agent/telegram.env
test "$(sudo stat -c '%a %U' /etc/agent/telegram.env)" = "600 root"
sudo sed 's/=.*/=.../' /etc/agent/telegram.env
```

If the token ever leaks, open @BotFather, send `/revoke`, pick the bot, and repeat step 3 with the new token.
