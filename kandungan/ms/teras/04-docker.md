# 4. Docker, tanpa membuka lubang pada firewall

**Jawapan ringkas:** pasang Docker dari repositori pakej Docker sendiri, hadkan saiz log bekas, dan terbitkan port bekas
pada `127.0.0.1` sahaja. Port yang diterbitkan cara biasa (`-p {{config:port.ejen_dalaman}}:80`) boleh dicapai dari
seluruh internet walaupun `ufw` dari bab 3 menyekatnya, kerana Docker menulis peraturan firewallnya sendiri di hadapan
`ufw`. Langkah di bawah menunjukkan perkara ini dari komputer anda, kemudian menutup lubang itu.

Diuji pada: {{diuji:teras/04-docker}}.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah ada firewall dari bab 3. Langkah bertanda "di
komputer anda" dijalankan dalam terminal di mesin anda sendiri.

## 1. Pasang Docker dari repositori Docker

Pakej `docker.io` Ubuntu sering ketinggalan beberapa versi. Ini arahan dari halaman pemasangan Docker: tambah kunci
tandatangan Docker, tambah repositori untuk keluaran Ubuntu anda, pasang enjin dan pemalam Compose.

{{langkah:teras/04-docker/pasang}}

Panduan ini menjalankan Docker dengan `sudo` dan tidak menambah pengguna anda ke kumpulan `docker`. Ahli kumpulan itu
sama seperti memegang root tanpa kata laluan, jadi penyerang yang masuk ke akaun anda akan menguasai seluruh pelayan.

## 2. Kecilkan log bekas

Secara lalai Docker menyimpan setiap baris yang dicetak bekas, selama-lamanya. Ejen yang merekod setiap mesej boleh
memenuhkan cakera kecil dalam beberapa minggu. Pemacu log `local` di bawah menyimpan paling banyak tiga fail 10 MB bagi
setiap bekas. Ia terpakai pada bekas yang dicipta selepas perubahan ini.

{{langkah:teras/04-docker/log}}

## 3. Semak Docker berfungsi

{{langkah:teras/04-docker/hello}}

## 4. Lihat masalahnya: port yang diterbitkan melepasi `ufw`

Mulakan pelayan web kecil dalam bekas dan terbitkan pada port {{config:port.ejen_dalaman}}, seperti kebanyakan contoh
di internet. Baris pertama menunjukkan `ufw` aktif.

{{langkah:teras/04-docker/terbit-semua}}

Sekarang semak dari komputer anda. Bab 3 sudah menyekat port ini, tetapi ia tetap menjawab:

{{langkah:teras/04-docker/terbit-semua-luar}}

Docker menghantar trafik port yang diterbitkan melalui rantaian `iptables` miliknya, yang disemak oleh kernel sebelum
peraturan `ufw`. `ufw status` juga tidak memaparkan port ini, jadi firewall nampak tertutup sedangkan ia terbuka.

## 5. Terbitkan pada `127.0.0.1` sahaja

Letakkan `127.0.0.1:` di hadapan port. Bekas itu kemudian boleh dicapai oleh program di pelayan (seperti proksi
terbalik dalam bab 5) dan tidak dari tempat lain.

{{langkah:teras/04-docker/terbit-tempatan}}

Semak sekali lagi dari komputer anda:

{{langkah:teras/04-docker/terbit-tempatan-luar}}

## 6. Peraturan yang sama dalam Docker Compose

Kebanyakan ejen datang dengan `compose.yaml`. Sebelum memulakannya, lihat setiap baris `ports:` dan pastikan ia bermula
dengan `127.0.0.1:`. Ini contoh kecil:

{{langkah:teras/04-docker/compose}}

Dari komputer anda:

{{langkah:teras/04-docker/compose-luar}}

Jika satu servis tidak perlu dicapai dari pelayan langsung (contohnya pangkalan data yang hanya dipakai bekas lain),
buang baris `ports:` servis itu. Bekas dalam fail Compose yang sama mencapai satu sama lain melalui nama servis tanpa
sebarang port diterbitkan.

## 7. Kemas

Buang bekas dan imej ujian. Docker kekal dipasang untuk bab ejen.

{{langkah:teras/04-docker/kemas}}
