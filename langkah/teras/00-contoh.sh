#!/usr/bin/env bash
# Bab contoh: membuktikan aliran alat ujian (bekas Ubuntu baharu, langkah satu demi satu, pelayan palsu, bukti).
# Bukan bab panduan. Jalankan: python3 alat/uji.py teras/00-contoh
# @perlu palsu

# @langkah semak-os
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu

# @langkah pasang-curl
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null
curl --version | sed -n 1p

# @langkah model-palsu
curl -fsS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "palsu-model", "messages": [{"role": "user", "content": "hello"}]}' \
  | grep -o '"content": "[^"]*"'

# @langkah telegram-palsu
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/getMe" | grep '"ok": true' >/dev/null
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id=1001 -d text="test message" \
  | grep -o '"text": "[^"]*"'
