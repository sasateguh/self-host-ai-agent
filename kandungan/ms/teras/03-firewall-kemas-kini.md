# 3. Firewall dan kemas kini automatik

**Jawapan ringkas:** pasang kemas kini terkini, kemudian hidupkan `ufw` supaya hanya SSH boleh sampai ke pelayan dari
luar, dan hidupkan `unattended-upgrades` supaya pembaikan keselamatan dipasang sendiri setiap hari. Langkah di bawah
memulakan pelayan web sementara pada port {{config:port.ejen_dalaman}} dan menyemaknya dari komputer anda sebelum dan
selepas firewall, jadi anda melihat firewall menyekat port yang benar-benar sedang mendengar.

Diuji pada: {{diuji:teras/03-firewall-kemas-kini}}.

Jalankan langkah ini sebagai pengguna dari bab 2 (`ssh {{config:contoh.pengguna}}@{{config:contoh.ip_vps}}`). Langkah
bertanda "di komputer anda" dijalankan dalam terminal di mesin anda sendiri.

## 1. Pasang kemas kini

Jika baris terakhir menyatakan but semula diperlukan, jalankan `sudo reboot`, tunggu seminit dan log masuk semula.

{{langkah:teras/03-firewall-kemas-kini/kemas-kini}}

## 2. Mulakan pelayan ujian sementara

Ini menghidangkan folder kosong pada port {{config:port.ejen_dalaman}}, port yang mungkin didengar oleh ejen kelak.

{{langkah:teras/03-firewall-kemas-kini/pelayan-cuba}}

## 3. Semak dari luar (di komputer anda)

Tanpa firewall, sesiapa boleh sampai kepadanya.

{{langkah:teras/03-firewall-kemas-kini/sebelum}}

## 4. Hidupkan firewall

Peraturan ini menyekat setiap sambungan masuk kecuali SSH, dan membenarkan semua sambungan keluar (kemas kini, penyedia
model, Telegram). Benarkan SSH sebelum `ufw enable`, atau firewall memutuskan sesi anda sendiri.

{{langkah:teras/03-firewall-kemas-kini/ufw}}

## 5. Semak semula (di komputer anda)

Pelayan ujian masih berjalan, tetapi port itu kini disekat dari luar, manakala SSH kekal terbuka.

{{langkah:teras/03-firewall-kemas-kini/selepas}}

Bab 5 membuka port {{config:port.http}} dan {{config:port.https}} untuk HTTPS. Ejen sendiri tidak pernah memerlukan port
terbuka: proksi terbalik mencapainya di dalam pelayan. Docker boleh menerbitkan port melepasi `ufw`; bab 4 menunjukkan
cara mengelakkannya.

## 6. Hentikan pelayan ujian

{{langkah:teras/03-firewall-kemas-kini/henti-pelayan-cuba}}

## 7. Hidupkan kemas kini keselamatan automatik

`unattended-upgrades` memasang pembaikan keselamatan sekali sehari. Dua tetapan di bawah menghidupkan muat semula senarai
pakej harian dan naik taraf itu sendiri. Larian cubaan di hujung menunjukkan apa yang akan dibuatnya sekarang, tanpa
mengubah apa-apa.

{{langkah:teras/03-firewall-kemas-kini/kemas-kini-automatik}}

Sesetengah pembaikan, seperti kernel baharu, hanya berkuat kuasa selepas but semula. Semak `/var/run/reboot-required`
bila anda log masuk, atau baca bab 9 untuk pemantauan yang memberitahu anda.
