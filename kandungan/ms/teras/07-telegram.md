# 7. Bot Telegram untuk pelayan anda

**Jawapan ringkas:** cipta bot melalui @BotFather di Telegram, tampal tokennya ke dalam fail yang hanya boleh dibaca
root, hantar satu mesej kepada bot itu dari telefon anda, kemudian cari ID sembang anda dan hantar mesej ujian kembali.
Bab ejen dan pemantauan dalam bab 9 memakai bot dan fail ini.

Diuji pada: {{diuji:teras/07-telegram}}.

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

{{langkah:teras/07-telegram/alat}}

## 3. Simpan token dalam fail khas root

Arahan ini mencipta `/etc/agent`, yang hanya boleh dibaca root, dan satu fail di dalamnya dengan mod `600`. Arahan
terakhir menunggu anda menampal token dan menekan Enter. Ia membaca token tanpa memaparkannya, jadi token tidak muncul di
skrin, dalam sejarah shell, atau dalam senarai proses yang berjalan. `TELEGRAM_API_URL` ialah alamat API Telegram;
biarkan seperti itu.

{{langkah:teras/07-telegram/simpan-token}}

## 4. Semak token

Ini bertanya kepada Telegram siapa bot itu dan mencetak nama penggunanya. Token dihantar kepada `curl` melalui input
standard, bukan pada baris arahan, jadi pengguna lain di pelayan tidak dapat melihatnya dalam senarai proses.

{{langkah:teras/07-telegram/semak-bot}}

Jika anda nampak `401 Unauthorized`, token tersalah tampal. Jalankan langkah 3 sekali lagi.

## 5. Cari ID sembang anda

Bot menyenaraikan mesej yang menunggunya. Anda patut nampak mesej `/start` anda dengan satu nombor di hadapannya: nombor
itu ialah ID sembang anda. Baris terakhir menyimpannya ke fail yang sama.

{{langkah:teras/07-telegram/id-sembang}}

Jika senarai kosong, hantar satu lagi mesej kepada bot dari telefon anda dan jalankan langkah ini semula.

## 6. Hantar mesej ujian

Mesej sampai ke telefon anda dan arahan mencetak teksnya.

{{langkah:teras/07-telegram/hantar}}

## 7. Semak fail

Fail mesti bermod `600` dan dimiliki root. Arahan terakhir memaparkan nama tetapan dengan nilainya disembunyikan.

{{langkah:teras/07-telegram/kebenaran}}

Jika token pernah bocor, buka @BotFather, hantar `/revoke`, pilih bot itu, dan ulang langkah 3 dengan token baharu.
