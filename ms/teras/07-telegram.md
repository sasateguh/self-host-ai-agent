<!-- generated from kandungan/ms/teras/07-telegram.md by alat/bina.py: edit the template, not this file -->
# 7. Bot Telegram untuk pelayan anda

**Jawapan ringkas:** cipta bot melalui @BotFather di Telegram, tampal tokennya ke dalam fail yang hanya boleh dibaca
root, hantar satu mesej kepada bot itu dari telefon anda, kemudian cari ID sembang anda dan hantar mesej ujian kembali.
Bab ejen dan pemantauan dalam bab 9 memakai bot dan fail ini.

Diuji pada: `ubuntu:24.04` (VM), 2026-10-26.

Jalankan langkah ini sebagai pengguna dari bab 2. Larian ujian bercakap dengan pengganti API Telegram, jadi tiada bot
sebenar dipakai.

## 1. Cipta bot (di telefon anda)

1. Dalam Telegram, buka sembang dengan **@BotFather** (pastikan ada tanda biru disahkan; ada akaun tiruan).
2. Hantar `/newbot`, kemudian nama paparan, kemudian nama pengguna yang berakhir dengan `bot`.
3. BotFather membalas dengan token yang rupanya seperti `123456789:AA...`. Sesiapa yang memegangnya menguasai bot itu.
   Jangan tampal token ke dalam sembang, tangkapan skrin atau fail yang anda komit.
4. Buka sembang dengan bot baharu anda dan hantar apa-apa mesej, contohnya `/start`. Bot tidak boleh menulis kepada anda
   dahulu, dan langkah 4 di bawah mencari ID sembang anda dari mesej ini.

## 2. Pasang alat

```bash
sudo apt-get update
sudo apt-get install -y curl jq
```

## 3. Simpan token dalam fail khas root

Arahan ini mencipta `/etc/agent`, yang hanya boleh dibaca root, dan satu fail di dalamnya dengan mod `600`. Arahan
terakhir menunggu anda menampal token dan menekan Enter. Ia membaca token tanpa memaparkannya, jadi token tidak muncul di
skrin, dalam sejarah shell, atau dalam senarai proses yang berjalan. `TELEGRAM_API_URL` ialah alamat API Telegram;
biarkan seperti itu.

```bash
sudo install -d -m 700 /etc/agent
sudo install -m 600 /dev/null /etc/agent/telegram.env
echo "TELEGRAM_API_URL=${TELEGRAM_API_URL:-https://api.telegram.org}" | sudo tee /etc/agent/telegram.env >/dev/null
sudo bash -c 'read -rsp "Paste the bot token, then press Enter: " t; echo; echo "TELEGRAM_BOT_TOKEN=$t" >> /etc/agent/telegram.env'
```

## 4. Semak token

Ini bertanya kepada Telegram siapa bot itu dan mencetak nama penggunanya. Token dihantar kepada `curl` melalui input
standard, bukan pada baris arahan, jadi pengguna lain di pelayan tidak dapat melihatnya dalam senarai proses.

```bash
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/getMe"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K - | jq -r '.result.username'
```

Jika anda nampak `401 Unauthorized`, token tersalah tampal. Jalankan langkah 3 sekali lagi.

## 5. Cari ID sembang anda

Bot menyenaraikan mesej yang menunggunya. Anda patut nampak mesej `/start` anda dengan satu nombor di hadapannya: nombor
itu ialah ID sembang anda. Baris terakhir menyimpannya ke fail yang sama.

```bash
. <(sudo cat /etc/agent/telegram.env)
updates="$(printf 'url = "%s/bot%s/getUpdates"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" | curl -fsS -K -)"
jq -r '.result[].message | "\(.chat.id) \(.from.first_name): \(.text)"' <<<"$updates"
chat_id="$(jq -er '.result[-1].message.chat.id' <<<"$updates")"
echo "TELEGRAM_CHAT_ID=$chat_id" | sudo tee -a /etc/agent/telegram.env >/dev/null
```

Jika senarai kosong, hantar satu lagi mesej kepada bot dari telefon anda dan jalankan langkah ini semula.

## 6. Hantar mesej ujian

Mesej sampai ke telefon anda dan arahan mencetak teksnya.

```bash
. <(sudo cat /etc/agent/telegram.env)
printf 'url = "%s/bot%s/sendMessage"\n' "$TELEGRAM_API_URL" "$TELEGRAM_BOT_TOKEN" \
  | curl -fsS -K - -d chat_id="$TELEGRAM_CHAT_ID" --data-urlencode text="Hello from your server" \
  | jq -r '.result.text'
```

## 7. Semak fail

Fail mesti bermod `600` dan dimiliki root. Arahan terakhir memaparkan nama tetapan dengan nilainya disembunyikan.

```bash
sudo stat -c '%a %U %n' /etc/agent /etc/agent/telegram.env
test "$(sudo stat -c '%a %U' /etc/agent/telegram.env)" = "600 root"
sudo sed 's/=.*/=.../' /etc/agent/telegram.env
```

Jika token pernah bocor, buka @BotFather, hantar `/revoke`, pilih bot itu, dan ulang langkah 3 dengan token baharu.
