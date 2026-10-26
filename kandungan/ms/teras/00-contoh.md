# Cara setiap arahan diuji

**Jawapan ringkas:** arahan setiap bab disimpan dalam fail langkah. Alat ujian menjalankan fail itu, satu langkah demi
satu, dalam bekas Ubuntu baharu (atau mesin maya untuk bab SSH dan firewall) dan merekod kod keluar setiap langkah. Bab
yang anda baca dijana daripada fail yang sama, jadi arahan yang tidak diuji tidak boleh muncul di dalamnya.

Diuji pada: {{diuji:teras/00-contoh}}.

Bab contoh ini bukan sebahagian daripada pemasangan. Ia menunjukkan format yang diikut oleh bab lain.

## 1. Semak sistem pengendalian

Mesin ujian mesti keluaran Ubuntu yang disasarkan panduan ini ({{config:ubuntu.versi}}).

{{langkah:teras/00-contoh/semak-os}}

## 2. Pasang pakej

{{langkah:teras/00-contoh/pasang-curl}}

## 3. Bercakap dengan penyedia model

Ujian tidak pernah memakai penyedia model atau kunci sebenar. Alat ujian memulakan penyedia palsu yang memakai API yang
sama dan menetapkan `OPENAI_BASE_URL` serta `OPENAI_API_KEY` supaya menghala kepadanya. Di pelayan anda sendiri, dua nilai
ini datang daripada penyedia anda.

{{langkah:teras/00-contoh/model-palsu}}

## 4. Hantar mesej Telegram

Begitu juga Telegram: dalam ujian, `TELEGRAM_API_URL` menghala ke pelayan Bot API palsu, jadi tiada mesej keluar dari
mesin ujian.

{{langkah:teras/00-contoh/telegram-palsu}}
