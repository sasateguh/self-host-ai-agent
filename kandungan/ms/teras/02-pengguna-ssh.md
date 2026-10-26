# 2. Akaun pengguna dan kunci SSH

**Jawapan ringkas:** cipta pengguna biasa dengan hak `sudo`, beri kunci SSH anda kepadanya, dan sahkan anda boleh log
masuk sebagai pengguna itu. Kemudian tetapkan pelayan SSH supaya menerima kunci sahaja dan menolak `root`. Langkah
terakhir membuktikannya dari komputer anda sendiri: log masuk kata laluan ditolak, begitu juga `root`.

Diuji pada: {{diuji:teras/02-pengguna-ssh}}.

Langkah bertanda "di komputer anda" dijalankan dalam terminal di komputer riba atau meja anda. Yang lain dijalankan di
pelayan, dalam sesi `ssh root@{{config:contoh.ip_vps}}` dari bab 1. Gantikan `{{config:contoh.ip_vps}}` dengan alamat
pelayan anda dan `{{config:contoh.pengguna}}` dengan nama pengguna yang anda mahu.

## 1. Semak kunci anda (di komputer anda)

Ini mencetak cap jari kunci yang anda beri kepada penyedia. Jika fail itu tiada, cipta kunci dengan
`ssh-keygen -t ed25519` dan pilih frasa laluan, kemudian tambah fail `.pub` ke pelayan dalam panel penyedia.

{{langkah:teras/02-pengguna-ssh/kunci-anda}}

## 2. Log masuk sebagai root (di komputer anda)

{{langkah:teras/02-pengguna-ssh/masuk-root}}

## 3. Lihat apa yang pelayan terima sekarang (di komputer anda)

Ini bertanya kepada pelayan kaedah log masuk yang ditawarkannya, tanpa log masuk. Pelayan baharu selalunya menyenaraikan
`password` di sebelah `publickey`. Maksudnya sesiapa di internet boleh mencuba kata laluan terhadapnya.

{{langkah:teras/02-pengguna-ssh/sebelum}}

## 4. Cipta pengguna

Pengguna itu tiada kata laluan pada mulanya, menyertai kumpulan `sudo`, dan menerima salinan kunci yang dibenarkan untuk
root, jadi kunci yang sama boleh log masuk. Kata laluan rawak untuk `sudo` ditulis ke fail yang hanya root boleh baca.

{{langkah:teras/02-pengguna-ssh/cipta-pengguna}}

Baca kata laluan itu dengan `cat /root/{{config:contoh.pengguna}}-sudo-password.txt` dan simpan dalam pengurus kata
laluan anda. Anda menaipnya bila `sudo` meminta. Langkah 9 memadam fail itu.

## 5. Log masuk sebagai pengguna baharu (di komputer anda)

Biarkan sesi root terbuka sehingga langkah 8 lulus. Jika ada yang tidak kena, anda masih boleh membaikinya dari situ
(atau dari konsol web penyedia).

{{langkah:teras/02-pengguna-ssh/masuk-pengguna}}

## 6. Benarkan kunci sahaja, tolak root

Tetapan diletak dalam fail sendiri, bukan dengan menyunting `/etc/ssh/sshd_config`. Ubuntu membaca setiap fail dalam
`/etc/ssh/sshd_config.d/`, dan penyedia selalunya meletak fail di situ yang menghidupkan semula kata laluan. `sshd -t`
menyemak sintaks sebelum muat semula, jadi salah taip tidak boleh menghentikan SSH. Baris terakhir gagal kecuali
ketiga-tiga tetapan berkuat kuasa.

{{langkah:teras/02-pengguna-ssh/kunci-ssh}}

## 7. Buktikan kata laluan ditolak (di komputer anda)

Pelayan kini mesti menyenaraikan `publickey` sahaja.

{{langkah:teras/02-pengguna-ssh/kata-laluan-ditolak}}

## 8. Buktikan root ditolak (di komputer anda)

{{langkah:teras/02-pengguna-ssh/root-ditolak}}

{{langkah:teras/02-pengguna-ssh/masuk-semula}}

Mulai sekarang, log masuk dengan `ssh {{config:contoh.pengguna}}@{{config:contoh.ip_vps}}` dan letak `sudo` di hadapan
arahan yang mengubah sistem. Anda boleh menutup sesi root.

## 9. Padam fail kata laluan

{{langkah:teras/02-pengguna-ssh/buang-fail-kata-laluan}}

Seterusnya: [3. Firewall dan kemas kini automatik](03-firewall-kemas-kini.md).
