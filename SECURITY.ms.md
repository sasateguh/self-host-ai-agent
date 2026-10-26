# Keselamatan

English: [SECURITY.md](SECURITY.md)

Panduan ini mengajar orang meletakkan pelayan di internet, jadi kesilapan di dalamnya boleh membiarkan pelayan sebenar
terbuka. Kami menganggap laporan tentang panduan ini sendiri sebagai laporan keselamatan.

## Apa yang patut dilaporkan

- Langkah yang membiarkan port, servis atau fail terbuka kepada internet walaupun bab itu menyatakan ia tertutup.
- Langkah yang meletakkan kunci API, token bot atau kata laluan di tempat pengguna atau bekas lain boleh membacanya, atau
  ke dalam log, imej atau sejarah shell.
- Langkah yang melemahkan SSH, firewall atau kemas kini automatik yang dipasang dalam bab sebelumnya.
- Masalah dalam alat ujian (`alat/`, `uji/`) yang membuat langkah yang gagal kelihatan lulus.

Kesilapan dalam ejen itu sendiri (Hermes Agent, OpenClaw) milik projek masing-masing. Sila laporkan di sana; beritahu kami
juga jika sesuatu bab perlu berubah kerananya.

## Cara melapor

Guna "Report a vulnerability" pada tab Security repo ini, atau emel hello@sasateguh.com dengan perkataan "security" dalam
subjek. Sertakan bab, id langkah (`# @langkah <id>`) dan apa yang anda lihat. Jangan buka isu awam untuk masalah yang
mendedahkan pelayan sehingga pembaikan diterbitkan.

Kami cuba membalas dalam masa 7 hari. Bila pembaikan mengubah sesuatu langkah, bab itu diuji semula dan perubahan
disenaraikan dalam [CHANGELOG.md](CHANGELOG.md).

## Versi yang diselenggara

Hanya cawangan main semasa diselenggara. Setiap bab menyatakan imej Ubuntu dan tarikh langkahnya terakhir lulus, dan
setiap bab ejen menyatakan versi ejen yang digunakan semasa ujian.
