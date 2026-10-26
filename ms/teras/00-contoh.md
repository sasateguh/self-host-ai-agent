<!-- generated from kandungan/ms/teras/00-contoh.md by alat/bina.py: edit the template, not this file -->
# Cara setiap arahan diuji

**Jawapan ringkas:** arahan setiap bab disimpan dalam fail langkah. Alat ujian menjalankan fail itu, satu langkah demi
satu, dalam bekas Ubuntu baharu (atau mesin maya untuk bab SSH dan firewall) dan merekod kod keluar setiap langkah. Bab
yang anda baca dijana daripada fail yang sama, jadi arahan yang tidak diuji tidak boleh muncul di dalamnya.

Diuji pada: `ubuntu:24.04`, 2026-10-26.

Bab contoh ini bukan sebahagian daripada pemasangan. Ia menunjukkan format yang diikut oleh bab lain.

## 1. Semak sistem pengendalian

Mesin ujian mesti keluaran Ubuntu yang disasarkan panduan ini (24.04).

```bash
. /etc/os-release
echo "$PRETTY_NAME"
test "$ID" = ubuntu
```

## 2. Pasang pakej

```bash
apt-get update -qq
apt-get install -y -qq --no-install-recommends curl ca-certificates >/dev/null
curl --version | sed -n 1p
```

## 3. Bercakap dengan penyedia model

Ujian tidak pernah memakai penyedia model atau kunci sebenar. Alat ujian memulakan penyedia palsu yang memakai API yang
sama dan menetapkan `OPENAI_BASE_URL` serta `OPENAI_API_KEY` supaya menghala kepadanya. Di pelayan anda sendiri, dua nilai
ini datang daripada penyedia anda.

```bash
curl -fsS "$OPENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "palsu-model", "messages": [{"role": "user", "content": "hello"}]}' \
  | grep -o '"content": "[^"]*"'
```

## 4. Hantar mesej Telegram

Begitu juga Telegram: dalam ujian, `TELEGRAM_API_URL` menghala ke pelayan Bot API palsu, jadi tiada mesej keluar dari
mesin ujian.

```bash
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/getMe" | grep '"ok": true' >/dev/null
curl -fsS "$TELEGRAM_API_URL/bot$TELEGRAM_BOT_TOKEN/sendMessage" -d chat_id=1001 -d text="test message" \
  | grep -o '"text": "[^"]*"'
```
