# 9. Pemantauan dan kemas kini

**Jawapan ringkas:** satu skrip kecil menyemak cakera, ingatan, servis yang gagal, bekas yang rosak dan but semula yang
tertunda setiap 15 minit, dan menghantar mesej Telegram kepada anda bila senarai itu berubah, termasuk "all clear" bila
masalah sudah hilang. Bekas dikemas kini dengan menukar tag versi yang dipin, menarik imej dan mencipta semula bekas;
berundur ialah langkah yang sama dengan tag lama. Langkah di bawah merosakkan satu servis dengan sengaja untuk melihat
amaran, kemudian mengemas kini dan mengundurkan satu bekas.

Diuji pada: {{diuji:teras/09-pantau}}.

Jalankan langkah ini sebagai pengguna dari bab 2, pada pelayan yang sudah melalui bab 3 (kemas kini keselamatan
automatik), bab 4 (Docker) dan bab 7 (bot Telegram). Larian ujian menghantar mesejnya kepada pengganti API Telegram.

## 1. Skrip semakan

Dua had di bahagian atas skrip ialah peratus; ubah ikut pelayan anda. `check-server print` hanya mencetak senarai semasa
dan tidak menghantar apa-apa.

{{langkah:teras/09-pantau/skrip}}

Skrip mengingati senarai terakhir yang dihantarnya dalam `/var/lib/check-server/last`, jadi masalah yang berlarutan
sepanjang malam memberi anda satu mesej, bukan satu setiap 15 minit.

## 2. Jalankan setiap 15 minit

{{langkah:teras/09-pantau/jadual}}

## 3. Cuba satu amaran

Ini memulakan servis sementara yang gagal dengan sengaja, kemudian menjalankan semakan. Mesej Telegram menyenaraikan
`check-demo.service` sebagai gagal, dan senarai yang disimpan menunjukkan perkara sama.

{{langkah:teras/09-pantau/cuba-amaran}}

## 4. Padamkan amaran

Menyuruh systemd melupakan servis yang gagal itu menghilangkan masalah. Semakan seterusnya menghantar "all clear".

{{langkah:teras/09-pantau/padam-amaran}}

Bila amaran sebenar sampai, lihat servis itu dengan `systemctl status <nama>` dan `journalctl -u <nama> -n 50`.
Untuk bekas, guna `sudo docker logs --tail 50 <nama>`. Untuk "a reboot is needed", jalankan `sudo reboot` pada waktu
lapang.

## 5. Pin versi bekas

Kemas kini keselamatan Ubuntu dipasang sendiri (bab 3). Bekas tidak: ia hanya berubah bila anda mengubahnya. Tulis tag
versi yang tepat dalam `compose.yaml` (jangan `latest`), supaya anda sentiasa tahu apa yang berjalan dan boleh berundur.
Contoh ini menjalankan keluaran Alpine yang lebih lama:

{{langkah:teras/09-pantau/versi-dipin}}

## 6. Kemas kini

Baca nota keluaran projek itu dahulu, kemudian tukar tag, tarik imej baharu dan cipta semula bekas. Semakan selepas itu
mengesahkan tiada apa yang rosak.

{{langkah:teras/09-pantau/kemas-kini}}

Ambil backup (bab 6) sebelum mengemas kini apa-apa yang menyimpan data.

## 7. Berundur

Jika versi baharu bermasalah, letak semula tag lama dan cipta semula bekas. Imej itu masih ada di pelayan, jadi ini
berfungsi tanpa internet.

{{langkah:teras/09-pantau/undur}}

## 8. Kemas

Buang projek contoh dan imejnya. Skrip semakan dan pemasanya kekal.

{{langkah:teras/09-pantau/kemas}}
