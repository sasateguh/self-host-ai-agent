# <Nama ejen> di pelayan anda

**Jawapan ringkas:** dua atau tiga ayat yang menjawab "bagaimana saya menjalankan ejen ini di pelayan sendiri" dengan
sendirinya: imej rasmi mana, bagaimana kunci dan token bot sampai kepadanya, bagaimana pembaca bercakap dengannya,
bagaimana ia dibackup dan dikemas kini.

Diuji pada: {{diuji:ejen/<nama>}}, dengan <Nama ejen> {{ejen:<nama>.ejen.versi}} (dikeluarkan
{{ejen:<nama>.ejen.tarikh_keluaran}}).

Satu perenggan tentang ejen itu, pembuatnya, lesennya ({{ejen:<nama>.ejen.lesen}}), kod sumber
({{ejen:<nama>.ejen.repo}}) dan dokumentasi ({{ejen:<nama>.ejen.dokumen}}).

Jalankan langkah ini sebagai pengguna dari bab 2, atas pelayan yang sudah melalui bab 3 (firewall), 4 (Docker),
6 (backup), 7 (bot Telegram) dan 8 (kunci API model). Larian ujian memakai penyedia model tiruan dan API Telegram
tiruan, kunci rekaan, dan mesej ujian sebagai ganti mesej yang ditaip di telefon.

## 1. Muat turun versi yang diuji

{{langkah:ejen/<nama>/tarik}}

## 2. Tulis fail tetapan

{{langkah:ejen/<nama>/config}}

## 3. Pilih model

{{langkah:ejen/<nama>/model}}

## 4. Mulakan ejen dengan Docker Compose

{{langkah:ejen/<nama>/compose}}

## 5. Tunggu sambungan Telegram

{{langkah:ejen/<nama>/sedia}}

## 6. Hantar mesej pertama

{{langkah:ejen/<nama>/mesej}}

## 7. Pastikan kunci dan token tidak bocor

{{langkah:ejen/<nama>/semak-bocor}}

## 8. Pastikan tiada apa-apa terbuka ke internet

{{langkah:ejen/<nama>/port-luar}}

## 9. Masukkan ejen ke backup harian

{{langkah:ejen/<nama>/backup}}

## 10. Latih pemulihan

{{langkah:ejen/<nama>/pulih}}

## 11. Kemas kini, dan undur bila perlu

{{langkah:ejen/<nama>/undur}}

{{langkah:ejen/<nama>/kemas-kini}}

## 12. Nyahpasang

{{langkah:ejen/<nama>/nyahpasang}}

---

Tersekat pada satu langkah? Sasa Teguh Academy menjalankan sesi pemasangan berpandu: https://academy.sasateguh.com
