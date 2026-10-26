# 6. Backup yang sudah anda pulihkan

**Jawapan ringkas:** guna `restic` untuk mengambil backup data ejen yang disulitkan setiap malam, simpan satu salinan di
komputer anda sendiri, dan berlatih memulihkan sebelum anda memerlukannya. Backup yang tidak pernah dipulihkan hanyalah
tekaan. Langkah di bawah memadam data dengan sengaja, memulihkannya, dan membandingkan setiap fail dengan yang asal.

Diuji pada: {{diuji:teras/06-backup-pulih}}.

Jalankan langkah ini sebagai pengguna dari bab 2. Langkah bertanda "di komputer anda" dijalankan dalam terminal di
mesin anda sendiri.

Bab ejen menyimpan data dalam folder masing-masing dan menambahnya ke backup. Di sini `/srv/agent-data` hanya memegang
beberapa fail ujian, jadi latihan pulih tidak boleh merosakkan apa-apa.

## 1. Cipta data ujian

Arahan terakhir merekod cincangan setiap fail, supaya hasil pulih boleh dibandingkan dengan yang asal kemudian.

{{langkah:teras/06-backup-pulih/data-contoh}}

## 2. Pasang restic

{{langkah:teras/06-backup-pulih/pasang-restic}}

## 3. Cipta repositori backup

Repositori disulitkan dengan kata laluan rawak yang disimpan dalam `/root/restic-password`. **Tanpa kata laluan itu,
backup tidak boleh dibaca oleh sesiapa, termasuk anda.** Salin ke pengurus kata laluan anda sekarang:
`sudo cat /root/restic-password`.

Repositori dijadikan boleh dibaca oleh pengguna anda (`{{config:contoh.pengguna}}`) supaya anda boleh menyalinnya ke
komputer anda tanpa root. Isinya disulitkan, jadi ini tidak mendedahkan data.

{{langkah:teras/06-backup-pulih/repositori}}

## 4. Skrip backup

Skrip ini membuat backup folder itu, menyimpan 7 snapshot harian dan 4 mingguan, memadam yang lebih lama, dan menyemak
repositori. Untuk backup folder lain kelak, tambahkannya selepas `/srv/agent-data` pada baris `restic backup`.

{{langkah:teras/06-backup-pulih/skrip}}

## 5. Jalankan setiap malam

Pemasa systemd menjalankan skrip pada 03:30 waktu pelayan, ditambah lengah rawak sehingga 15 minit. `Persistent=true`
bermakna backup yang terlepas semasa pelayan mati dijalankan sebaik sahaja ia hidup semula.

{{langkah:teras/06-backup-pulih/jadual}}

## 6. Ambil backup pertama sekarang

{{langkah:teras/06-backup-pulih/backup-pertama}}

## 7. Salin backup keluar dari pelayan (di komputer anda)

Backup yang hanya ada di pelayan hilang bersama pelayan. Tarik satu salinan ke komputer anda sendiri. `rsync` hanya
memindahkan apa yang berubah, jadi menjalankannya semula kemudian adalah pantas. Jalankan selepas setiap backup yang
penting, atau secara berjadual di komputer anda.

{{langkah:teras/06-backup-pulih/salin-luar}}

Untuk memulihkan dari salinan ini di mesin lain, pasang restic di situ dan halakan ke folder `agent-backup` dengan kata
laluan dari langkah 3.

## 8. Latihan pulih: padam data

Lakukan ini sekarang, semasa folder itu hanya memegang data ujian. Kelak, dengan data sebenar, berlatih dengan memulihkan
ke folder berasingan (`--target /tmp/restore-test`) dan membandingkannya.

{{langkah:teras/06-backup-pulih/padam}}

## 9. Pulihkan dan bandingkan

`restic restore latest` mengembalikan snapshot terbaharu. Perbandingan tidak mencetak apa-apa jika setiap fail sama
dengan yang asal, kemudian baris terakhir mengesahkannya.

{{langkah:teras/06-backup-pulih/pulih}}

Ulang latihan ini setiap beberapa bulan, dan selepas sebarang perubahan pada skrip backup.
