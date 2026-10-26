#!/usr/bin/env bash
# Bab teras 7: bot Telegram. Token ditampal ke fail root 0600 (tidak dalam sejarah shell atau senarai proses), ID sembang
# dicari dari getUpdates, mesej ujian dihantar. Telegram = palsu (PRD K5); "pembaca" sudah menghantar /start kepada bot
# (config [palsu] mesej_awal) dan token ditampal dari [palsu.tampal] token_bot.
# Jalankan: python3 alat/uji.py teras/07-telegram
# @perlu vm palsu

# @langkah alat
sudo apt-get update
sudo apt-get install -y curl jq

# @langkah simpan-token
# @tampal token_bot
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/telegram.env
echo "TELEGRAM_API_URL=${TELEGRAM_API_URL:-https://api.telegram.org}" | sudo tee /etc/agent/telegram.env >/dev/null
sudo bash -c 'read -rsp "Paste the bot token, then press Enter: " t; echo; echo "TELEGRAM_BOT_TOKEN=$t" >> /etc/agent/telegram.env'

# @langkah semak-bot
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/getMe"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K - | jq -r '.result.username'

# @langkah id-sembang
. <(sudo cat /etc/agent/telegram.env)
updates="$(printf 'url = "%s/bot%s/getUpdates"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K -)"
jq -r '.result[].message | "\(.chat.id) \(.from.first_name): \(.text)"' <<<"$updates"
chat_id="$(jq -er '.result[-1].message.chat.id' <<<"$updates")"
echo "TELEGRAM_CHAT_ID=$chat_id" | sudo tee -a /etc/agent/telegram.env >/dev/null

# @langkah hantar
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/sendMessage"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" \
  | curl -fsS -K - -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="Hello from your server" \
  | jq -r '.result.text'

# @langkah kebenaran
sudo stat -c '%a %U %n' /etc/agent /etc/agent/telegram.env
test "$(sudo stat -c '%a %U' /etc/agent/telegram.env)" = "600 root"
sudo sed 's/=.*/=.../' /etc/agent/telegram.env
